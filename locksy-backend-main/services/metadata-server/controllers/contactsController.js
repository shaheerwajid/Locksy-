/*
 * Contacts Controller for Metadata Server
 * Handles contact metadata operations with cache-aside pattern
 */

const { response } = require('express');
const Contacto = require('../../../models/contacto');
const Usuario = require('../../../models/usuario');
const cacheService = require('../../cache/cacheService');

// Socket.IO and Firebase Admin - try to import, fallback gracefully if not available
let io = null;
let admin = null;
try {
  const socketModule = require('../../../sockets/socket');
  io = socketModule.io || null;
  admin = socketModule.admin || null;
} catch (error) {
  console.warn('Socket.IO not available in Metadata Server:', error.message);
}

/**
 * Send Firebase notification
 * Note: In a fully separated architecture, this would use a message queue
 */
const sendFirebaseNotification = (usuario, title, body) => {
  if (!usuario?.firebaseid || !admin) {
    // If admin not available, queue notification instead
    try {
      const { sendNotification } = require('../../notification/producer');
      sendNotification({
        token: usuario?.firebaseid,
        title,
        body,
        data: { type: 'contact' }
      }).catch(err => console.error('Error queueing notification:', err));
    } catch (error) {
      console.warn('Notification queue not available:', error.message);
    }
    return;
  }

  const message = {
    notification: {
      title: title,
      body: body
    },
    data: {
      type: 'contact'
    },
    token: usuario.firebaseid,
    android: {
      priority: 'high'
    }
  };

  admin.messaging()
    .send(message)
    .then((response) => {
      console.log('Successfully sent notification:', response);
    })
    .catch((error) => {
      console.error('Error sending notification:', error);
    });
};

/**
 * Create contact
 * Invalidates contact caches
 */
const createContacto = async (req, res = response) => {
  try {
    const usuarioUsuario = await Usuario.findOne({
      codigoContacto: req.body.codigoUsuario
    });
    const usuarioContacto = await Usuario.findOne({
      codigoContacto: req.body.codigoContacto
    });

    if (!usuarioUsuario || !usuarioContacto) {
      return res.status(404).json({
        ok: false,
        msg: 'Usuario no encontrado'
      });
    }

    sendFirebaseNotification(
      usuarioContacto,
      'Contact request',
      'You have received a contact request'
    );

    // Check if contact already exists
    const existeContacto = await Contacto.findOne({
      usuario: usuarioUsuario._id,
      contacto: usuarioContacto._id
    });

    if (existeContacto) {
      return res.status(400).json({
        ok: false,
        msg: existeContacto.activo == '1'
          ? 'El Contacto ya ha sido registrado'
          : 'Ya existe una solicitud pendiente'
      });
    }

    const contacto = new Contacto({
      fecha: req.body.fecha,
      activo: req.body.activo,
      fechausuario: req.body.fechausuario,
      usuario: usuarioUsuario._id,
      contacto: usuarioContacto._id,
      publicKey: usuarioContacto.publicKey
    });

    await contacto.save();

    // Queue notification (async, don't block)
    try {
      const { queueNotification } = require('../../notification/producer');
      await queueNotification({
        userId: usuarioContacto._id.toString(),
        title: 'Solicitud de contacto',
        body: `${usuarioUsuario.nombre} te envió una solicitud de contacto`,
        data: {
          type: 'contact_request',
          contactId: contacto._id.toString(),
          from: usuarioUsuario._id.toString()
        }
      }).catch(err => console.error('Notification error:', err));
    } catch (error) {
      console.error('Error queueing notification:', error);
    }

    // Trigger feed generation (async, don't block)
    try {
      const feedGenerator = require('../../feed/generator');
      await feedGenerator.triggerFeedGeneration('contact', {
        usuario: usuarioUsuario._id.toString(),
        contacto: usuarioContacto._id.toString()
      }).catch(err => console.error('Feed generation error:', err));
    } catch (error) {
      console.error('Error triggering feed generation:', error);
    }

    // Invalidate cache
    await Promise.all([
      cacheService.deletePattern(`contacts:${usuarioUsuario._id}:*`),
      cacheService.deletePattern(`contacts:${usuarioContacto._id}:*`)
    ]).catch(err => console.error('Cache invalidation error:', err));

    res.json({
      ok: true,
      contacto
    });
  } catch (error) {
    console.error('Error creating contacto:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al crear contacto'
    });
  }
};

/**
 * Get contacts (solicitudes)
 * Cache: 15 minutes
 */
const getContactos = async (req, res = response) => {
  try {
    const usuarioUsuario = await Usuario.findOne({
      codigoContacto: req.body.code
    });

    if (!usuarioUsuario) {
      return res.status(404).json({
        ok: false,
        msg: 'Usuario no encontrado'
      });
    }

    const activo = req.body.activo;
    const cacheKey = `contacts:${usuarioUsuario._id}:${activo}`;

    // Try cache first
    const cached = await cacheService.get(cacheKey);
    if (cached) {
      return res.json({
        ...cached,
        cached: true
      });
    }

    const solicitudes = await Contacto.find({
      activo: { $eq: activo },
      contacto: { $eq: usuarioUsuario._id }
    })
      .populate('usuario')
      .populate('contacto')
      .lean();

    const result = {
      ok: true,
      solicitudes,
      cached: false
    };

    // Cache result (15 minutes)
    await cacheService.set(cacheKey, result, 900);

    res.json(result);
  } catch (error) {
    console.error('Error getting contactos:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al obtener contactos'
    });
  }
};

/**
 * Get contact list
 * Cache: 15 minutes
 */
const getListadoContactos = async (req, res = response) => {
  try {
    const miCodigo = req.body.code;
    const usuario = await Usuario.findOne({ codigoContacto: miCodigo });

    if (!usuario) {
      return res.status(404).json({
        ok: false,
        msg: 'Usuario no encontrado'
      });
    }

    const cacheKey = `contacts:${usuario._id}:list`;

    // Try cache first
    const cached = await cacheService.get(cacheKey);
    if (cached) {
      return res.json({
        ...cached,
        cached: true
      });
    }

    const blockUsers = usuario?.blockUsers?.map((id) => id.toString()) || [];

    const listContactos = await Contacto.find({
      $and: [
        {
          activo: '1',
          $or: [
            { contacto: { $eq: usuario._id } },
            { usuario: { $eq: usuario._id } }
          ]
        },
        {
          contacto: { $nin: blockUsers },
          usuario: { $nin: blockUsers }
        }
      ]
    })
      .populate('usuario')
      .populate('contacto')
      .lean()
      .filter((contacto) => contacto.usuario && contacto.contacto);

    if (!listContactos) {
      return res.json({
        ok: true,
        listContactos: [],
        cached: false
      });
    }

    const result = {
      ok: true,
      listContactos,
      cached: false
    };

    // Cache result (15 minutes)
    await cacheService.set(cacheKey, result, 900);

    res.json(result);
  } catch (error) {
    console.error('Error getting listado contactos:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al obtener lista de contactos'
    });
  }
};

/**
 * Activate contact
 * Invalidates contact caches
 */
const activateContacto = async (req, res = response) => {
  try {
    const usuarioUsuario = await Usuario.findOne({
      codigoContacto: req.body.codigoUsuario
    });
    const usuarioContacto = await Usuario.findOne({
      codigoContacto: req.body.codigoContacto
    });

    if (!usuarioUsuario || !usuarioContacto) {
      return res.status(404).json({
        ok: false,
        msg: 'Usuario no encontrado'
      });
    }

    sendFirebaseNotification(
      usuarioUsuario,
      'Contact request accepted',
      'Your contact request has been accepted.'
    );

    const contacto = await Contacto.findOne({
      usuario: usuarioUsuario._id,
      contacto: usuarioContacto._id
    });

    if (!contacto) {
      return res.status(404).json({
        ok: false,
        msg: 'Contacto no encontrado'
      });
    }

    contacto.activo = '1';
    await contacto.save();

    // Queue notification (async, don't block)
    try {
      const { queueNotification } = require('../../notification/producer');
      await queueNotification({
        userId: usuarioUsuario._id.toString(),
        title: 'Solicitud aceptada',
        body: `${usuarioContacto.nombre} aceptó tu solicitud de contacto`,
        data: {
          type: 'contact_accepted',
          contactId: contacto._id.toString(),
          from: usuarioContacto._id.toString()
        }
      }).catch(err => console.error('Notification error:', err));
    } catch (error) {
      console.error('Error queueing notification:', error);
    }

    // Trigger feed generation (async, don't block)
    try {
      const feedGenerator = require('../../feed/generator');
      await feedGenerator.triggerFeedGeneration('contact', {
        usuario: usuarioUsuario._id.toString(),
        contacto: usuarioContacto._id.toString()
      }).catch(err => console.error('Feed generation error:', err));
    } catch (error) {
      console.error('Error triggering feed generation:', error);
    }

    // Invalidate cache
    await Promise.all([
      cacheService.deletePattern(`contacts:${usuarioUsuario._id}:*`),
      cacheService.deletePattern(`contacts:${usuarioContacto._id}:*`)
    ]).catch(err => console.error('Cache invalidation error:', err));

    res.json({
      ok: true
    });
  } catch (error) {
    console.error('Error activating contacto:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al activar contacto'
    });
  }
};

/**
 * Delete contact
 * Invalidates contact caches
 */
const dropContacto = async (req, res = response) => {
  try {
    const usuarioUsuario = await Usuario.findOne({
      codigoContacto: req.body.codigoUsuario
    });
    const usuarioContacto = await Usuario.findOne({
      codigoContacto: req.body.codigoContacto
    });

    if (!usuarioUsuario || !usuarioContacto) {
      return res.status(404).json({
        ok: false,
        msg: 'Usuario no encontrado'
      });
    }

    // Try to find contact in both directions
    let contacto = await Contacto.findOne({
      $and: [
        { usuario: { $eq: usuarioUsuario._id } },
        { contacto: { $eq: usuarioContacto._id } }
      ]
    });

    if (!contacto) {
      contacto = await Contacto.findOne({
        $and: [
          { contacto: { $eq: usuarioUsuario._id } },
          { usuario: { $eq: usuarioContacto._id } }
        ]
      });
    }

    if (contacto) {
      await contacto.remove();
    }

    // Invalidate cache
    await Promise.all([
      cacheService.deletePattern(`contacts:${usuarioUsuario._id}:*`),
      cacheService.deletePattern(`contacts:${usuarioContacto._id}:*`)
    ]).catch(err => console.error('Cache invalidation error:', err));

    res.json({
      ok: true
    });
  } catch (error) {
    console.error('Error dropping contacto:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al eliminar contacto'
    });
  }
};

/**
 * Update contact disappear time
 */
const updatContactDisappearTime = async (req, res = response) => {
  try {
    if (
      !req.body.disappearMessageSetAt ||
      !req.body.disappearMessageTime ||
      (!req.body.contacto && !req.body.usuario)
    ) {
      return res.status(400).json({
        ok: false,
        message: 'Missing properties'
      });
    }

    const contacto = await Contacto.findOne({
      contacto: req.body.contacto,
      usuario: req.body.usuario
    });

    if (!contacto) {
      return res.status(404).json({
        ok: false,
        message: 'No contact found'
      });
    }

    contacto.disappearMessageSetAt = new Date(req.body.disappearMessageSetAt);
    contacto.disappearMessageTime = req.body.disappearMessageTime;
    contacto.disappearedCheck = true;
    await contacto.save();

    // Invalidate cache
    await cacheService.deletePattern(`contacts:${req.body.usuario}:*`);

    res.json({
      ok: true
    });
  } catch (error) {
    console.error('Error updating contact disappear time:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al actualizar tiempo de desaparición'
    });
  }
};

/**
 * Reject call handler
 */
const rejectCallHandler = async (req, res = response) => {
  try {
    if (io) {
      io.to(req.body.callerId).emit('rejectCall', { data: 'rejected' });
    } else {
      // If socket.io not available, this should be handled by main app
      console.warn('Socket.IO not available for reject call');
    }
    res.json({
      ok: true
    });
  } catch (error) {
    console.error('Error in reject call handler:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al rechazar llamada'
    });
  }
};

module.exports = {
  createContacto,
  getContactos,
  getListadoContactos,
  activateContacto,
  dropContacto,
  updatContactDisappearTime,
  rejectCallHandler
};

