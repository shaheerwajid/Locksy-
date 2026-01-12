/*
 * Users Controller for Metadata Server
 * Handles user metadata operations with cache-aside pattern
 */

const { response } = require('express');
const fs = require('fs');
const bcrypt = require('bcryptjs');
const Usuario = require('../../../models/usuario');
const Pago = require('../../../models/pago');
const generalesHelper = require('../../../helpers/generales');
const { isValidPublicKey } = require('../../../helpers/cryptoServer');
const cacheService = require('../../cache/cacheService');
const fun = require('../../../helpers/funciones');

/**
 * Get all users (paginated)
 * Cache: 15 minutes
 */
const getUsuarios = async (req, res = response) => {
  try {
    const desde = Number(req.query.desde) || 0;
    const cacheKey = `users:list:${desde}`;
    
    // Try cache first
    const cached = await cacheService.get(cacheKey);
    if (cached) {
      return res.json({
        ...cached,
        cached: true
      });
    }

    // Fetch from database
    const usuarios = await Usuario.find({ _id: { $ne: req.uid } })
      .sort('-online')
      .skip(desde)
      .lean();

    const result = {
      ok: true,
      usuarios,
      cached: false
    };

    // Cache result (15 minutes)
    await cacheService.set(cacheKey, result, 900);

    res.json(result);
  } catch (error) {
    console.error('Error getting usuarios:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al obtener usuarios'
    });
  }
};

/**
 * Get user by code or uid
 * Supports both legacy (uid) and new (code) formats
 * Cache: 1 hour
 */
const getUsuario = async (req, res = response) => {
  try {
    const code = req.body.code;
    const uid = req.body.uid;
    
    if (!code && !uid) {
      return res.status(400).json({
        ok: false,
        msg: 'Code or uid is required'
      });
    }

    let usuario;
    let cacheKey;
    
    if (uid) {
      // Get by user ID (legacy support)
      cacheKey = `user:id:${uid}`;
      
      // Try cache first
      const cached = await cacheService.get(cacheKey);
      if (cached) {
        return res.json({
          ...cached,
          cached: true
        });
      }
      
      // Fetch from database
      usuario = await Usuario.findById(uid).lean();
    } else {
      // Get by contact code
      cacheKey = `user:code:${code}`;
      
      // Try cache first
      const cached = await cacheService.get(cacheKey);
      if (cached) {
        return res.json({
          ...cached,
          cached: true
        });
      }
      
      // Fetch from database
      usuario = await Usuario.findOne({
        codigoContacto: { $eq: code }
      }).lean();
    }

    // Format result to match legacy response
    const result = {
      usuario: usuario ? (Array.isArray(usuario) ? usuario : [usuario]) : [],
      cached: false
    };

    // Cache result (1 hour) if found
    if (usuario) {
      await cacheService.set(cacheKey, result, 3600);
      // Also cache by the other key if we have both
      if (uid && usuario.codigoContacto) {
        await cacheService.set(`user:code:${usuario.codigoContacto}`, result, 3600);
      } else if (code && usuario._id) {
        await cacheService.set(`user:id:${usuario._id}`, result, 3600);
      }
    }

    res.json(result);
  } catch (error) {
    console.error('Error getting usuario:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al obtener usuario'
    });
  }
};

/**
 * Update user
 * Invalidates user cache
 */
const updateUsuario = async (req, res = response) => {
  try {
    const usuario = await Usuario.findOne({
      _id: { $eq: req.body.uid }
    });

    if (!usuario) {
      return res.status(404).json({
        ok: false,
        msg: 'Usuario no encontrado'
      });
    }

    // Update fields
    if (req.body.nuevo != null && req.body.nuevo != '') {
      usuario.nuevo = req.body.nuevo;
    }
    if (req.body.avatar != null && req.body.avatar != '') {
      usuario.avatar = req.body.avatar;
    }
    if (req.body.nombre != null && req.body.nombre != '') {
      usuario.nombre = req.body.nombre;
    }
    if (req.body.email != null && req.body.email != '') {
      usuario.email = req.body.email;
    }
    if (req.body.online === true) {
      usuario.online = true;
      usuario.lastSeen = new Date();
    }
    if (req.body.online === false) {
      usuario.online = false;
    }
    if (req.body.fcmToken === 'remove') {
      usuario.firebaseid = '';
    }

    // Password update
    if (req.body.clave != null && req.body.clave != '') {
      const salt = bcrypt.genSaltSync();
      const newClave = bcrypt.hashSync(req.body.clave, salt);
      const validPassword = bcrypt.compareSync(
        req.body.oldClave,
        usuario.password
      );
      if (!validPassword) {
        return res.json({
          ok: false,
          error: 'ERR103'
        });
      }
      usuario.password = newClave;
    }

    await usuario.save();

    // Index user for search (async, don't block)
    try {
      const indexer = require('../../search/indexer');
      await indexer.indexUser(usuario).catch(err => console.error('Search indexing error:', err));
    } catch (error) {
      console.error('Error indexing user:', error);
    }

    // Invalidate cache
    await Promise.all([
      cacheService.invalidateUser(usuario._id.toString()),
      cacheService.deletePattern(`user:code:${usuario.codigoContacto}`),
      cacheService.deletePattern('users:list:*')
    ]).catch(err => console.error('Cache invalidation error:', err));

    res.json({
      ok: 'MSG101',
      error: false
    });
  } catch (error) {
    console.error('Error updating usuario:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al actualizar usuario'
    });
  }
};

/**
 * Block user
 */
const blockUsers = async (req, res = response) => {
  try {
    const userIdToBlock = req.body.uid;
    if (userIdToBlock === req.uid) {
      return res.status(400).json({
        ok: false,
        message: 'Error'
      });
    }

    const updatedUser = await Usuario.findOneAndUpdate(
      { _id: req.uid },
      { $addToSet: { blockUsers: userIdToBlock } },
      { new: true }
    );

    if (!updatedUser) {
      return res.status(404).json({
        ok: false,
        msg: 'Usuario no encontrado'
      });
    }

    // Invalidate cache
    await cacheService.invalidateUser(req.uid.toString());

    res.json({
      ok: true,
      updatedUser
    });
  } catch (error) {
    console.error('Error blocking user:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al bloquear usuario'
    });
  }
};

/**
 * Unblock user
 */
const unBlockUsers = async (req, res = response) => {
  try {
    const userIdToUnblock = req.body.uid;

    const updatedUser = await Usuario.findOneAndUpdate(
      { _id: req.uid },
      { $pull: { blockUsers: userIdToUnblock } },
      { new: true }
    );

    if (!updatedUser) {
      return res.status(404).json({
        ok: false,
        message: 'User not found'
      });
    }

    // Invalidate cache
    await cacheService.invalidateUser(req.uid.toString());

    res.status(200).json({
      ok: true,
      message: 'User unblocked successfully',
      updatedUser
    });
  } catch (error) {
    console.error('Error unblocking user:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al desbloquear usuario'
    });
  }
};

/**
 * Get public key
 * Cache: 1 hour
 */
const obtenerPublicKey = async (req, res = response) => {
  try {
    const { id } = req.params;
    const cacheKey = `user:${id}:public-key`;

    // Try cache first
    const cached = await cacheService.get(cacheKey);
    if (cached) {
      return res.json({
        ...cached,
        cached: true
      });
    }

    const usuario = await Usuario.findById(id)
      .select('publicKey nombre codigoContacto email')
      .lean();

    if (!usuario) {
      return res.status(404).json({
        ok: false,
        msg: 'Usuario no encontrado'
      });
    }

    const result = {
      ok: true,
      usuario: {
        uid: usuario._id.toString(),
        nombre: usuario.nombre,
        email: usuario.email,
        codigoContacto: usuario.codigoContacto,
        publicKey: usuario.publicKey || null
      },
      cached: false
    };

    // Cache result (1 hour)
    await cacheService.set(cacheKey, result, 3600);

    res.json(result);
  } catch (error) {
    console.error('Error obteniendo public key:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al obtener public key'
    });
  }
};

/**
 * Update public key
 */
const actualizarPublicKey = async (req, res = response) => {
  try {
    const { publicKey } = req.body;
    const uid = req.uid;

    if (!publicKey) {
      return res.status(400).json({
        ok: false,
        msg: 'Public key es requerido'
      });
    }

    if (!isValidPublicKey(publicKey)) {
      return res.status(400).json({
        ok: false,
        msg: 'Invalid public key format'
      });
    }

    const usuario = await Usuario.findById(uid);
    if (!usuario) {
      return res.status(404).json({
        ok: false,
        msg: 'Usuario no encontrado'
      });
    }

    usuario.publicKey = publicKey;
    await usuario.save();

    // Invalidate cache
    await Promise.all([
      cacheService.invalidateUser(uid.toString()),
      cacheService.deletePattern(`user:${uid}:public-key`)
    ]).catch(err => console.error('Cache invalidation error:', err));

    res.json({
      ok: true,
      usuario: {
        ...usuario.toJSON(),
        publicKey: usuario.publicKey
      }
    });
  } catch (error) {
    console.error('Error actualizando public key:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al actualizar public key'
    });
  }
};

/**
 * Update/regenerate encryption keys
 */
const actualizarKeys = async (req, res = response) => {
  try {
    const { publicKey, privateKey, password } = req.body;
    const uid = req.uid;

    if (!publicKey || !privateKey) {
      return res.status(400).json({
        ok: false,
        msg: 'Public key and private key are required',
      });
    }

    // Validate public key format
    if (!isValidPublicKey(publicKey)) {
      return res.status(400).json({
        ok: false,
        msg: 'Invalid public key format',
      });
    }

    const usuario = await Usuario.findById(uid).select('+password');
    if (!usuario) {
      return res.status(404).json({
        ok: false,
        msg: 'Usuario no encontrado',
      });
    }

    // Verify password if provided (for security)
    if (password) {
      const bcrypt = require('bcryptjs');
      const validPassword = bcrypt.compareSync(password, usuario.password);
      if (!validPassword) {
        return res.status(400).json({
          ok: false,
          msg: 'Invalid password',
        });
      }
    }

    // Update public key
    usuario.publicKey = publicKey;

    // Encrypt and store private key
    const { encryptPrivateKey } = require('../../helpers/keyEncryption');
    try {
      const encryptedPrivateKey = encryptPrivateKey(privateKey, password || usuario.password);
      usuario.encryptedPrivateKey = encryptedPrivateKey;
      console.log('[Metadata Server] ✅ Keys updated and encrypted for user:', usuario.email);
    } catch (error) {
      console.error('[Metadata Server] ❌ Error encrypting private key:', error);
      return res.status(500).json({
        ok: false,
        msg: 'Error encrypting private key',
      });
    }

    await usuario.save();

    // Invalidate cache
    await Promise.all([
      cacheService.invalidateUser(uid.toString()),
      cacheService.deletePattern(`user:${uid}:public-key`)
    ]).catch(err => console.error('Cache invalidation error:', err));

    res.json({
      ok: true,
      msg: 'Keys updated successfully',
      usuario: {
        ...usuario.toJSON(),
        publicKey: usuario.publicKey,
        // Don't send privateKey back - it's already on the client
      },
    });
  } catch (error) {
    console.error('Error actualizando keys:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al actualizar keys',
    });
  }
};

/**
 * Check if email exists
 */
const registerEmailCheck = async (req, res) => {
  try {
    const { email } = req.body;
    const usuarioDB = await Usuario.findOne({ email }).lean();

    if (usuarioDB) {
      res.json({
        ok: 'OK',
        error: ''
      });
    } else {
      res.status(400).json({
        ok: 'Not found',
        error: ''
      });
    }
  } catch (error) {
    res.status(400).json({
      ok: 'Not found',
      error: 'error'
    });
  }
};

/**
 * Password recovery step 1
 */
const recoveryPasswordS1 = async (req, res = response) => {
  try {
    const email = req.body.email;
    const usuario = await Usuario.findOne({ email });

    if (!usuario) {
      // Don't reveal if email exists for security
      return res.json({ ok: true });
    }

    const getLink = (usuario) => {
      const res = 'https://www.tollray.ninja/pms/recoverPassword/?id=';
      const solicitudes = generalesHelper.buscarSolicitudesCambioClave(usuario);
      if (solicitudes != false) {
        return res + solicitudes.length + fun.encrypt(usuario.nombre);
      }
      return res + '1' + fun.encrypt(usuario.nombre);
    };

    const urlArchivo = '/home/servidorPMS/public/formatos/emailRecuperacion.html';
    fs.readFile(urlArchivo, 'utf8', function (err, data) {
      if (err) {
        console.error('Error reading email template:', err);
        return res.json({ ok: true }); // Don't reveal error
      }

      const linkRecuperacion = getLink(usuario);
      let htmlMensaje = data;
      htmlMensaje = htmlMensaje.replace(/{USERNAME}/g, usuario.nombre);
      htmlMensaje = htmlMensaje.replace(/{EMAIL}/g, usuario.email);
      htmlMensaje = htmlMensaje.replace(/{LINK_RECOVERY}/g, linkRecuperacion);

      generalesHelper.guardarMail(
        'tollray.pms@gmail.com',
        usuario.email,
        'Recuperar contraseña - TollRay',
        htmlMensaje
      );
    });

    res.json({ ok: true });
  } catch (error) {
    console.error('Error in recovery password S1:', error);
    res.json({ ok: true }); // Don't reveal error
  }
};

/**
 * Password recovery step 2 (GET)
 */
const recoveryPasswordS2 = async (req, res = response) => {
  try {
    if (req.query.id == undefined) {
      return res.send(
        'Código de recuperación erroneo, este no es el camino que querías'
      );
    }

    const urlArchivo = './public/formatos/recuperarClave.html';
    fs.readFile(urlArchivo, 'utf8', function (err, data) {
      if (err) {
        return res.send('Error loading recovery page');
      }

      let html = data;
      const nombre = fun.decrypt(req.query.id.substring(1));

      Usuario.findOne({ nombre: nombre }).then((usuario) => {
        generalesHelper.buscarPreguntasUsuario(
          usuario.id,
          function (preguntas) {
            html = html.replace(/{USERNAME}/g, usuario.nombre);
            html = html.replace(/{PREGUNTA1}/g, preguntas.pregunta1);
            html = html.replace(/{PREGUNTA2}/g, preguntas.pregunta2);
            html = html.replace(/{PREGUNTA3}/g, preguntas.pregunta3);
            html = html.replace(/{PREGUNTA4}/g, preguntas.pregunta4);

            const validar =
              '' +
              '<button id="cmdValidar">Validar Información</button>   ' +
              '<script>                                               ' +
              '  $("#cmdValidar").click(function(){                   ' +
              '       $.ajax({                                        ' +
              '            method: "POST",                            ' +
              '            contentType: "application/json",           ' +
              '            url: "/api/usuarios/recovery-password-s2", ' +
              '            data: JSON.stringify({                     ' +
              '                   id: "' +
              preguntas.id_usuario +
              '", ' +
              '                   a1: $("#txtRespuesta1").val(),      ' +
              '                   a2: $("#txtRespuesta2").val(),      ' +
              '                   a3: $("#txtRespuesta3").val(),      ' +
              '                   a4: $("#txtRespuesta4").val(),})    ' +
              '        })                                             ' +
              '            .done(function( msg ) {                    ' +
              '               $("#div2").html(msg);                   ' +
              '               $("#div1").hide()                       ' +
              '            });                                        ' +
              '       })                                              ' +
              '</script>';

            html = html.replace(/{BOTON_RECOVERY}/g, validar);
            res.send(html);
          }
        );
      });
    });
  } catch (error) {
    console.error('Error in recovery password S2:', error);
    res.send('Error loading recovery page');
  }
};

/**
 * Validate security questions
 */
const validarPreguntas = async (req, res = response) => {
  try {
    const id = req.body.id;
    const a1 = req.body.a1;
    const a2 = req.body.a2;
    const a3 = req.body.a3;
    const a4 = req.body.a4;

    generalesHelper.buscarPreguntasUsuario(id, function (preguntas) {
      if (
        preguntas.respuesta1 != a1 ||
        preguntas.respuesta2 != a2 ||
        preguntas.respuesta3 != a3 ||
        preguntas.respuesta4 != a4
      ) {
        res.send('Las respuestas son incorrectas');
      } else {
        const urlArchivo = './public/formatos/cambiarClave.html';
        fs.readFile(urlArchivo, 'utf8', function (err, data) {
          if (err) {
            return res.send('Error loading change password page');
          }
          let html = data;
          html = html.replace(/{ID_USUARIO}/g, fun.encrypt(id));
          res.send(html);
        });
      }
    });
  } catch (error) {
    console.error('Error validating questions:', error);
    res.send('Error validating questions');
  }
};

/**
 * Change password
 */
const cambiarClave = async (req, res = response) => {
  try {
    const id = fun.decrypt(req.body.id);
    const salt = bcrypt.genSaltSync();
    const nuevaClave = bcrypt.hashSync(req.body.txtClave, salt);

    const usuario = await Usuario.findOne({ _id: { $eq: id } });
    if (!usuario) {
      return res.send('Usuario no encontrado');
    }

    usuario.password = nuevaClave;
    await usuario.save();

    // Invalidate cache
    await cacheService.invalidateUser(id.toString());

    const urlArchivo = './public/formatos/claveCambiada.html';
    fs.readFile(urlArchivo, 'utf8', function (err, data) {
      if (err) {
        return res.send('OK - Password changed');
      }
      res.send('OK' + data);
    });
  } catch (error) {
    console.error('Error changing password:', error);
    res.send('Error changing password');
  }
};

/**
 * Get payments
 */
const getPagos = async (req, res = response) => {
  try {
    const pagos = await Pago.find({ usuario: { $eq: req.body.uid } })
      .sort({ _id: -1 })
      .lean();

    res.json({
      ok: true,
      listPagos: pagos
    });
  } catch (error) {
    console.error('Error getting pagos:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al obtener pagos'
    });
  }
};

/**
 * Register payment
 */
const registrarPago = async (req, res = response) => {
  try {
    const d = new Date();
    d.setDate(d.getDate() + 30);

    const pago = new Pago(req.body);
    pago.fecha_fin = d.toISOString();
    await pago.save();

    res.json({
      ok: true,
      respuesta: 'OK',
      pago: pago
    });
  } catch (error) {
    console.error('Error registering pago:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al registrar pago'
    });
  }
};

/**
 * Register security questions
 */
const registrarPreguntas = async (req, res = response) => {
  try {
    const usuario = await Usuario.findOne({
      _id: { $eq: req.body.uid }
    });

    if (!usuario) {
      return res.status(404).json({
        ok: false,
        msg: 'Usuario no encontrado'
      });
    }

    generalesHelper.guardarPreguntas(
      usuario.id,
      req.body.pregunta1,
      req.body.respuesta1,
      req.body.pregunta2,
      req.body.respuesta2,
      req.body.pregunta3,
      req.body.respuesta3,
      req.body.pregunta4,
      req.body.respuesta4
    );

    usuario.nuevo = 'false';
    await usuario.save();

    // Invalidate cache
    await cacheService.invalidateUser(req.body.uid.toString());

    res.json({
      ok: 'MSG102',
      error: ''
    });
  } catch (error) {
    console.error('Error registering preguntas:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al registrar preguntas'
    });
  }
};

/**
 * Report
 */
const report = async (req, res = response) => {
  try {
    const usuario = await Usuario.findOne({
      _id: { $eq: req.body.uid }
    });

    if (!usuario) {
      return res.status(404).json({
        ok: false,
        msg: 'Usuario no encontrado'
      });
    }

    generalesHelper.insertReport(
      req.body.tipo,
      req.body.desc,
      req.body.uid,
      null
    );

    res.json({
      ok: 'OK',
      error: ''
    });
  } catch (error) {
    console.error('Error in report:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al registrar reporte'
    });
  }
};

module.exports = {
  getUsuarios,
  getUsuario,
  updateUsuario,
  blockUsers,
  unBlockUsers,
  obtenerPublicKey,
  actualizarPublicKey,
  actualizarKeys,
  registerEmailCheck,
  recoveryPasswordS1,
  recoveryPasswordS2,
  validarPreguntas,
  cambiarClave,
  getPagos,
  registrarPago,
  registrarPreguntas,
  report
};


