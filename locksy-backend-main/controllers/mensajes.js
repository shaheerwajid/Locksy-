const Mensaje = require('../models/mensaje');
const Usuario = require('../models/usuario');
const { isValidCiphertext } = require('../helpers/cryptoServer');
const cacheService = require('../services/cache/cacheService');

// Queue service stub (assuming it exists)
const queueService = {
  publish: (queue, payload) => {
    // Stub - replace with actual queue service
    try {
      const producer = require('../services/queue/producer');
      return producer.sendToQueue(queue, payload);
    } catch (error) {
      console.error('Queue service error:', error);
      return Promise.resolve(false);
    }
  }
};

const obtenerChat = async (req, res) => {
    try {
        const miId = req.uid;
        const mensajesDe = req.params.de;
        const limit = parseInt(req.query.limit) || 50;
        const skip = parseInt(req.query.skip) || 0;
        const after = req.query.after; // timestamp for pagination

        // Generate cache key
        const cacheKey = `chat:${miId}:${mensajesDe}:${limit}:${skip}:${after || 'latest'}`;

        // Try cache first
        const cached = await cacheService.get(cacheKey);
        if (cached) {
            return res.json({
                ok: true,
                mensajes: cached,
                cached: true,
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

        // Cache result (5 minutes TTL)
        await cacheService.set(cacheKey, mensajes, 300);

        res.json({
            ok: true,
            mensajes: mensajes.reverse(), // Reverse to show oldest first
            cached: false,
            hasMore: mensajes.length === limit,
        });
    } catch (error) {
        console.error('Error obteniendo chat:', error);
        res.status(500).json({
            ok: false,
            msg: "Error al obtener mensajes",
        });
    }
};

// New function: Create message (validates ciphertext only)
const crearMensaje = async (req, res) => {
    try {
        const { para, grupo, mensaje, incognito, forwarded, reply, parentType, parentSender, parentContent } = req.body;
        const de = req.uid;

        // Validate required fields
        if (!para || !mensaje) {
            return res.status(400).json({
                ok: false,
                msg: "Para y mensaje son requeridos",
            });
        }

        // Validate ciphertext format
        if (!mensaje.ciphertext || !isValidCiphertext(mensaje.ciphertext)) {
            return res.status(400).json({
                ok: false,
                msg: "Invalid ciphertext format",
            });
        }

        // Get sender user
        const usuario = await Usuario.findById(de);
        if (!usuario) {
            return res.status(404).json({
                ok: false,
                msg: "Usuario no encontrado",
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
                forwarded: mensaje.forwarded || false,
            },
            incognito: incognito || false,
            forwarded: forwarded || false,
            reply: reply || false,
            parentType: parentType || null,
            parentSender: parentSender || null,
            parentContent: parentContent || null,
            usuario: usuario._id,
        });

        await nuevoMensaje.save();

        // Populate usuario field
        await nuevoMensaje.populate('usuario', 'nombre avatar publicKey');

        // Index message for search (async, don't block)
        queueService.publish('indexing', {
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

        // Queue notification to recipient (async, don't block)
        // Skip notification if user is sending to themselves
        try {
            if (de !== para) { // Only send notification if sender != recipient
                const { queueNotification } = require('../services/notification/producer');
                const recipient = await Usuario.findById(para);
                if (recipient?.firebaseid) {
                    await queueNotification({
                        userId: para,
                        title: 'Nuevo mensaje',
                        body: `${usuario.nombre} te envió un mensaje`,
                        data: {
                            type: 'message',
                            messageId: nuevoMensaje._id.toString(),
                            senderId: de.toString(),
                            recipientId: para.toString()
                        }
                    }).catch(err => console.error('Notification error:', err));
                }
            }
        } catch (error) {
            console.error('Error queueing notification:', error);
        }

        // Trigger feed generation (async, don't block)
        try {
            const feedGenerator = require('../services/feed/generator');
            await feedGenerator.triggerFeedGeneration('message', {
                para: para,
                grupo: grupo || null
            }).catch(err => console.error('Feed generation error:', err));
        } catch (error) {
            console.error('Error triggering feed generation:', error);
        }

        // Invalidate cache
        const cacheKey = `chat:${de}:${para}:*`;
        await cacheService.deletePattern(cacheKey).catch(() => {});

        res.json({
            ok: true,
            mensaje: nuevoMensaje,
        });
    } catch (error) {
        console.error('Error creando mensaje:', error);
        res.status(500).json({
            ok: false,
            msg: "Error al crear mensaje",
        });
    }
};

module.exports = {
    obtenerChat,
    crearMensaje,
};