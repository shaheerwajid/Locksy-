/*
 * Messages Controller for Metadata Server
 * Handles message metadata operations with cache-aside pattern
 */

const Mensaje = require('../../../models/mensaje');
const Usuario = require('../../../models/usuario');
const { isValidCiphertext } = require('../../../helpers/cryptoServer');
const cacheService = require('../../cache/cacheService');

/**
 * Get chat messages
 * Cache: 5 minutes
 */
const obtenerChat = async (req, res) => {
  try {
    const miId = req.uid;
    const mensajesDe = req.params.de;
    const limit = parseInt(req.query.limit) || 50;
    const skip = parseInt(req.query.skip) || 0;
    const after = req.query.after;

    // Generate cache key
    const cacheKey = `chat:${miId}:${mensajesDe}:${limit}:${skip}:${after || 'latest'}`;

    // Try cache first
    const cached = await cacheService.get(cacheKey);
    if (cached) {
      return res.json({
        ...cached,
        cached: true
      });
    }

    // Build query
    const query = {
      $or: [
        { de: miId, para: mensajesDe },
        { de: mensajesDe, para: miId }
      ]
    };

    // Add timestamp filter if provided
    if (after) {
      query.createdAt = { $lt: new Date(after) };
    }

    // Fetch from database
    const mensajes = await Mensaje.find(query)
      .sort({ createdAt: -1 })
      .limit(limit)
      .skip(skip)
      .populate('usuario', 'nombre avatar publicKey')
      .lean();

    const result = {
      ok: true,
      mensajes: mensajes.reverse(),
      cached: false,
      hasMore: mensajes.length === limit
    };

    // Cache result (5 minutes)
    await cacheService.set(cacheKey, result, 300);

    res.json(result);
  } catch (error) {
    console.error('Error obteniendo chat:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al obtener mensajes'
    });
  }
};

/**
 * Create message
 * Invalidates chat cache
 */
const crearMensaje = async (req, res) => {
  try {
    const { para, grupo, mensaje, incognito, forwarded, reply, parentType, parentSender, parentContent } = req.body;
    const de = req.uid;

    // Validate required fields
    if (!para || !mensaje) {
      return res.status(400).json({
        ok: false,
        msg: 'Para y mensaje son requeridos'
      });
    }

    // Validate ciphertext format
    if (!mensaje.ciphertext || !isValidCiphertext(mensaje.ciphertext)) {
      return res.status(400).json({
        ok: false,
        msg: 'Invalid ciphertext format'
      });
    }

    // Get sender user
    const usuario = await Usuario.findById(de);
    if (!usuario) {
      return res.status(404).json({
        ok: false,
        msg: 'Usuario no encontrado'
      });
    }

    // Create message
    const nuevoMensaje = new Mensaje({
      de,
      para,
      grupo: grupo || null,
      mensaje: {
        ciphertext: mensaje.ciphertext,
        type: mensaje.type || 'text',
        fileUrl: mensaje.fileUrl || null,
        fileSize: mensaje.fileSize || null,
        fileName: mensaje.fileName || null,
        mimeType: mensaje.mimeType || null,
        replyTo: mensaje.replyTo || null,
        forwarded: mensaje.forwarded || false
      },
      incognito: incognito || false,
      forwarded: forwarded || false,
      reply: reply || false,
      parentType: parentType || null,
      parentSender: parentSender || null,
      parentContent: parentContent || null,
      usuario: usuario._id
    });

    await nuevoMensaje.save();

    // Populate usuario field
    await nuevoMensaje.populate('usuario', 'nombre avatar publicKey');

    // Index message for search (async, don't block)
    try {
      const queueService = require('../../queue/producer');
      await queueService.sendToQueue('indexing', {
        type: 'message',
        action: 'index',
        data: {
          id: nuevoMensaje._id.toString(),
          de: de,
          para: para,
          grupo: grupo || null,
          createdAt: nuevoMensaje.createdAt,
          // Note: We don't index ciphertext for privacy
        }
      }).catch(err => console.error('Search indexing error:', err));
    } catch (error) {
      console.error('Error queueing search indexing:', error);
    }

    // Queue notification to recipient (async, don't block)
    try {
      const { queueNotification } = require('../../notification/producer');
      const recipient = await Usuario.findById(para);
      if (recipient?.firebaseid) {
        await queueNotification({
          userId: para,
          title: 'Nuevo mensaje',
          body: `${usuario.nombre} te envió un mensaje`,
          data: {
            type: 'message',
            messageId: nuevoMensaje._id.toString(),
            from: de,
            to: para
          }
        }).catch(err => console.error('Notification error:', err));
      }
    } catch (error) {
      console.error('Error queueing notification:', error);
    }

    // Trigger feed generation (async, don't block)
    try {
      const feedGenerator = require('../../feed/generator');
      await feedGenerator.triggerFeedGeneration('message', {
        para: para,
        grupo: grupo || null
      }).catch(err => console.error('Feed generation error:', err));
    } catch (error) {
      console.error('Error triggering feed generation:', error);
    }

    // Invalidate cache
    await Promise.all([
      cacheService.deletePattern(`chat:${de}:${para}:*`),
      cacheService.deletePattern(`chat:${para}:${de}:*`)
    ]).catch(err => console.error('Cache invalidation error:', err));

    res.json({
      ok: true,
      mensaje: nuevoMensaje
    });
  } catch (error) {
    console.error('Error creando mensaje:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al crear mensaje'
    });
  }
};

module.exports = {
  obtenerChat,
  crearMensaje
};


