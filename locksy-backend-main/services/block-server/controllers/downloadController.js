/*
 * Download Controller for Block Server
 * Handles file downloads and presigned URLs
 */

const { response } = require('express');
const fileService = require('../../storage/fileService');
const path = require('path');
const fs = require('fs');

/**
 * Download file
 */
const downloadFile = async (req, res = response) => {
  try {
    const fileId = req.params.fileId;

    // Check if file exists
    const exists = await fileService.fileExists(fileId);
    if (!exists) {
      return res.status(404).json({
        ok: false,
        msg: 'Archivo no encontrado'
      });
    }

    // Get file URL or path
    const fileUrl = fileService.getFileUrl(fileId);

    // If it's a local file, serve it directly
    if (fileUrl.startsWith('/') || fileUrl.startsWith('./')) {
      const filePath = path.resolve(__dirname, '../../../', fileUrl);
      if (fs.existsSync(filePath)) {
        return res.sendFile(filePath);
      }
    }

    // For remote storage, redirect to URL or return presigned URL
    res.json({
      ok: true,
      url: fileUrl
    });
  } catch (error) {
    console.error('Error downloading file:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al descargar archivo'
    });
  }
};

/**
 * Download chunk (for chunked downloads)
 */
const downloadChunk = async (req, res = response) => {
  try {
    const { fileId, chunkIndex } = req.params;

    // This would be implemented for chunked downloads
    // For now, return error as chunked downloads are not yet implemented
    res.status(501).json({
      ok: false,
      msg: 'Chunked downloads not yet implemented'
    });
  } catch (error) {
    console.error('Error downloading chunk:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al descargar chunk'
    });
  }
};

/**
 * Get presigned URL for file access
 */
const getPresignedUrl = async (req, res = response) => {
  try {
    const fileId = req.params.fileId;
    const expiresIn = parseInt(req.query.expiresIn) || 3600; // Default 1 hour

    const exists = await fileService.fileExists(fileId);
    if (!exists) {
      return res.status(404).json({
        ok: false,
        msg: 'Archivo no encontrado'
      });
    }

    const presignedUrl = await fileService.getPresignedUrl(fileId, expiresIn);

    res.json({
      ok: true,
      url: presignedUrl,
      expiresIn
    });
  } catch (error) {
    console.error('Error getting presigned URL:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al obtener URL firmada'
    });
  }
};

/**
 * Legacy: getFile (for backward compatibility)
 */
const getFile = async (req, res) => {
  try {
    const fileName = req.query.f;
    if (!fileName) {
      return res.status(400).json({
        ok: false,
        msg: 'File name is required'
      });
    }

    const urlFiles = './public/uploads/';
    const filePath = path.join(urlFiles, fileName);

    if (fs.existsSync(filePath)) {
      return res.sendFile(path.resolve(filePath));
    }

    res.status(404).json({
      ok: false,
      msg: 'Archivo no encontrado'
    });
  } catch (error) {
    console.error('Error getting file:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al obtener archivo'
    });
  }
};

module.exports = {
  downloadFile,
  downloadChunk,
  getPresignedUrl,
  getFile
};


