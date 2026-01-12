/*
 * Upload Controller for Block Server
 * Handles file uploads, chunked uploads, and video processing
 */

const { response } = require('express');
const fileService = require('../../storage/fileService');
const blockServer = require('../../storage/blockServer');
const producer = require('../../queue/producer');
const Mensaje = require('../../../models/mensaje');
const Usuario = require('../../../models/usuario');
const Grupo = require('../../../models/grupo');
const GrupoUsuario = require('../../../models/grupo_usuario');
const fs = require('fs');
const path = require('path');

/**
 * Upload file (regular or chunked based on size)
 */
const uploadFile = async (req, res = response) => {
  try {
    if (!req.file) {
      return res.status(400).json({
        ok: false,
        msg: 'No file uploaded'
      });
    }

    const file = req.file;
    const folder = req.body.folder || 'general';
    const fileType = req.body.type || 'general';

    // Determine folder based on file type
    let destinationFolder = folder;
    if (fileType === 'image') {
      destinationFolder = 'images';
    } else if (fileType === 'video') {
      destinationFolder = 'videos';
    } else if (fileType === 'audio') {
      destinationFolder = 'audio';
    } else if (fileType === 'document') {
      destinationFolder = 'documents';
    }

    // Use chunked upload for large files
    let result;
    if (file.size > fileService.chunkSize) {
      result = await fileService.uploadLargeFile(file, destinationFolder);
    } else {
      result = await fileService.uploadFile(file, destinationFolder);
    }

    // Queue video processing if it's a video
    if (fileType === 'video' || file.mimetype.startsWith('video/')) {
      try {
        await producer.sendVideoProcessing({
          fileId: result.path || result.url,
          originalPath: file.path,
          fileName: file.originalname,
          mimeType: file.mimetype,
          size: file.size,
          uploadedBy: req.uid
        });
      } catch (error) {
        console.error('Error queueing video processing:', error.message);
        // Don't fail the upload if video processing queue fails
      }
    }

    res.json({
      ok: true,
      file: result
    });
  } catch (error) {
    console.error('Error uploading file:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al subir archivo'
    });
  }
};

/**
 * Delete file
 */
const deleteFile = async (req, res = response) => {
  try {
    const fileId = req.params.fileId;
    
    await fileService.deleteFile(fileId);

    res.json({
      ok: true,
      msg: 'Archivo eliminado'
    });
  } catch (error) {
    console.error('Error deleting file:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al eliminar archivo'
    });
  }
};

/**
 * Get file info
 */
const getFileInfo = async (req, res = response) => {
  try {
    const fileId = req.params.fileId;
    
    const exists = await fileService.fileExists(fileId);
    if (!exists) {
      return res.status(404).json({
        ok: false,
        msg: 'Archivo no encontrado'
      });
    }

    const url = fileService.getFileUrl(fileId);

    res.json({
      ok: true,
      file: {
        id: fileId,
        url
      }
    });
  } catch (error) {
    console.error('Error getting file info:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al obtener información del archivo'
    });
  }
};

/**
 * Legacy: subirArchivos (for backward compatibility)
 * Handles file uploads with message creation
 */
const subirArchivos = async (req, res, next) => {
  try {
    const body = req.body;
    const archivos = req.files;
    let grupo;
    const receptores = [];

    if (Object.keys(body.grupo || {}).length === 0) {
      receptores.push(body.para);
    } else {
      grupo = await Grupo.findOne({ codigo: { $eq: body.para } });
      await Usuario.populate(grupo, {
        path: 'usuarioCrea',
        select: ['nombre', 'avatar', 'codigoContacto']
      });

      const grupoUsuarios = await GrupoUsuario.find({
        grupo: { $eq: grupo._id }
      }).populate('usuarioContacto');

      grupoUsuarios.forEach((groupUser) => {
        const usua = groupUser.usuarioContacto;
        if (body.de != usua._id.toString()) {
          receptores.push(usua._id.toString());
        }
      });
    }

    if (!archivos || archivos.length === 0) {
      return res.status(400).json({
        ok: false,
        msg: 'Please upload a file'
      });
    }

    const emisor = await Usuario.findById(body.de);
    if (!emisor) {
      return res.status(404).json({
        ok: false,
        msg: 'Usuario no encontrado'
      });
    }

    // Upload files and create messages
    for (const fileToSend of archivos) {
      if (!fileToSend) continue;

      // Upload file using file service
      const fileType = body.type || 'general';
      let folder = 'general';
      if (fileType === 'image') folder = 'images';
      else if (fileType === 'video') folder = 'videos';
      else if (fileType === 'audio') folder = 'audio';
      else if (fileType === 'document') folder = 'documents';

      const uploadResult = await fileService.uploadFile(fileToSend, folder);
      const fileUrl = uploadResult.url || uploadResult.path;

      // Queue video processing if video
      if (fileType === 'video' || fileToSend.mimetype?.startsWith('video/')) {
        try {
          await producer.sendVideoProcessing({
            fileId: fileUrl,
            originalPath: fileToSend.path,
            fileName: fileToSend.originalname,
            mimeType: fileToSend.mimetype,
            size: fileToSend.size,
            uploadedBy: body.de
          });
        } catch (error) {
          console.error('Error queueing video processing:', error.message);
        }
      }

      // Create messages for each recipient
      for (const recipt of receptores) {
        const mensaje = new Mensaje({
          de: body.de,
          para: recipt,
          usuario: emisor,
          mensaje: {
            extension: body.extension,
            fecha: body.fecha,
            type: body.type,
            content: fileUrl
          },
          forwarded: body.forwarded,
          grupo: grupo || null
        });

        await mensaje.save();

        // Emit socket event (if socket.io available)
        // Try to get Socket.IO from sockets module, fallback gracefully if not available
        try {
          let io = null;
          try {
            // Try to get from sockets module (if main server is running)
            const socketModule = require('../../../sockets/socket');
            io = socketModule.io || null;
          } catch (err) {
            // Socket.IO not available - this is OK for Block Server running standalone
            io = null;
          }
          
          if (io) {
            if (Object.keys(body.grupo || {}).length === 0) {
              io.to(mensaje.para).compress(true).emit('mensaje-personal', mensaje);
            } else {
              mensaje.de = body.para;
              io.to(mensaje.para).compress(true).emit('mensaje-grupal', mensaje);
            }
          }
        } catch (error) {
          // Socket.IO not available - this is OK, notifications will be sent via queue
          console.warn('Socket.IO not available for real-time messaging:', error.message);
        }

        // Send notification (queue it)
        try {
          const receptor = await Usuario.findById(recipt);
          if (receptor?.firebaseid) {
            await producer.sendNotification({
              token: receptor.firebaseid,
              title: 'Mensaje nuevo',
              body: 'Mensaje nuevo en CryptoChat',
              data: {
                type: 'message',
                messageId: mensaje._id.toString()
              }
            });
          }
        } catch (error) {
          console.error('Error sending notification:', error.message);
        }
      }
    }

    res.json({
      ok: true
    });
  } catch (error) {
    console.error('Error in subirArchivos:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al subir archivos'
    });
  }
};

/**
 * Get avatars list
 */
const getavatars = async (req, res) => {
  try {
    const folder = './public/avatars/';
    const listaAvatars = [];

    fs.readdir(folder, (err, files) => {
      if (err) {
        return res.status(500).json({
          ok: false,
          msg: 'Error al leer carpeta de avatares'
        });
      }

      files.forEach((file) => {
        listaAvatars.push(file);
      });

      res.json({
        ok: true,
        avatars: listaAvatars
      });
    });
  } catch (error) {
    console.error('Error getting avatars:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al obtener avatares'
    });
  }
};

/**
 * Get grupos images list
 */
const getgruposimg = async (req, res) => {
  try {
    const folder = './public/gruposImg/';
    const listaImagenes = [];

    fs.readdir(folder, (err, files) => {
      if (err) {
        return res.status(500).json({
          ok: false,
          msg: 'Error al leer carpeta de imágenes de grupos'
        });
      }

      files.forEach((file) => {
        listaImagenes.push(file);
      });

      res.json({
        ok: true,
        images: listaImagenes
      });
    });
  } catch (error) {
    console.error('Error getting grupos images:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al obtener imágenes de grupos'
    });
  }
};

module.exports = {
  uploadFile,
  deleteFile,
  getFileInfo,
  subirArchivos,
  getavatars,
  getgruposimg
};

