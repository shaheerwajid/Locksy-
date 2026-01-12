const { response } = require("express");
const fs = require("fs");
var fun = require("../helpers/funciones");
const bcrypt = require("bcryptjs");

const Usuario = require("../models/usuario");
const Pago = require("../models/pago");

const generalesHelper = require("../helpers/generales");
const { isValidPublicKey } = require("../helpers/cryptoServer");
const { encryptPrivateKey } = require("../helpers/keyEncryption");

const getUsuarios = async (req, res = response) => {
  const desde = Number(req.query.desde) || 0;
  const usuarios = await Usuario.find({ _id: { $ne: req.uid } })
    .sort("-online")
    .skip(desde);
  res.json({
    ok: true,
    usuarios,
  });
};

const getUsuario = async (req, res = response) => {
  const usuario = await Usuario.find({
    codigoContacto: { $eq: req.body.code },
  });
  res.json({
    usuario,
  });
};
const blockUsers = async (req, res = response) => {
  const userIdToBlock = req.body.uid; // The ID to add to the blockUsers array
  if (userIdToBlock === req.uid) {
    res.status(400).json({ message: "Error" });
    return;
  }
  const updatedUser = await Usuario.findOneAndUpdate(
    { _id: req.uid }, // Find user by codigoContacto
    { $addToSet: { blockUsers: userIdToBlock } }, // Add userId to blockUsers if not already present
    { new: true } // Return the updated document
  );
  res.json({
    updatedUser,
  });
};
const unBlockUsers = async (req, res = response) => {
  const userIdToUnblock = req.body.uid; // The ID to remove from the blockUsers array

  const updatedUser = await Usuario.findOneAndUpdate(
    { _id: req.uid }, // Find the user by their ID (current user's ID)
    { $pull: { blockUsers: userIdToUnblock } }, // Remove userId from blockUsers array
    { new: true } // Return the updated document
  );

  if (!updatedUser) {
    return res.status(404).json({ message: "User not found" });
  }

  res.status(200).json({
    message: "User unblocked successfully",
    updatedUser,
  });
};

const updateUsuario = async (req, res = response) => {
  try {
    const usuario = await Usuario.findOne({
      _id: { $eq: req.body.uid },
    });
    
    if (!usuario) {
      return res.status(404).json({
        ok: false,
        msg: "User not found"
      });
    }
    
    if (req.body.nuevo != null && req.body.nuevo != "")
      usuario.nuevo = req.body.nuevo;

    if (req.body.avatar != null && req.body.avatar != "")
      usuario.avatar = req.body.avatar;

    if (req.body.nombre != null && req.body.nombre != "")
      usuario.nombre = req.body.nombre;

    if (req.body.email != null && req.body.email != "")
      usuario.email = req.body.email;

    if (req.body.online === true) {
      usuario.online = true;
      usuario.lastSeen = new Date();
    }

    if (req.body.online === false) {
      usuario.online = false;
    }
    
    // Handle FCM token: remove or set
    if (req.body.fcmToken === "remove") {
      usuario.firebaseid = "";
      console.log('[updateUsuario] FCM token removed for user:', usuario._id);
    } else if (req.body.fcmToken != null && req.body.fcmToken !== "") {
      // Handle setting FCM token
      usuario.firebaseid = req.body.fcmToken.trim();
      console.log('[updateUsuario] ✅ FCM token updated for user:', usuario._id);
    }

    if (req.body.clave != null && req.body.clave != "") {
      const salt = bcrypt.genSaltSync();
      var newClave = bcrypt.hashSync(req.body.clave, salt);
      const validPassword = bcrypt.compareSync(
        req.body.oldClave,
        usuario.password
      );
      if (!validPassword) {
        return res.json({
          ok: false,
          error: "ERR103",
        });
      } else {
        usuario.password = newClave;
      }
    }
    
    await usuario.save();
    
    // Index user for search (async, don't block) - use setImmediate to ensure response is sent first
    setImmediate(() => {
      try {
        const indexer = require('../services/search/indexer');
        indexer.indexUser(usuario).catch(err => console.error('Search indexing error:', err));
      } catch (error) {
        console.error('Error indexing user:', error);
      }
    });
    
    return res.json({
      ok: "MSG101",
      error: false,
    });
  } catch (error) {
    console.error('Error updating user:', error);
    return res.status(500).json({
      ok: false,
      msg: "Error updating user"
    });
  }
};

const getLink = (usuario) => {
  // var res = "http://cliniapp.net:5000/pms/recoverPassword/?id=";
  var res = "https://www.tollray.ninja/pms/recoverPassword/?id=";
  var solicitudes = generalesHelper.buscarSolicitudesCambioClave(usuario);
  if (solicitudes != false) res += solicitudes.lenght;
  else res += 1;
  res += fun.encrypt(usuario.nombre);
  return res;
};

const recoveryPasswordS1 = async (req, res = response) => {
  console.log(req.connection.remoteAddress);
  const email = req.body.email;
  const usuario = await Usuario.findOne({ email: email }).then((usuario) => {
    var urlArchivo = "/home/servidorPMS/public/formatos/emailRecuperacion.html";
    fs.readFile(urlArchivo, "utf8", function (err, data) {
      if (err) return console.log(err);

      var linkRecuperacion = getLink(usuario);
      var htmlMensaje = data;
      htmlMensaje = htmlMensaje.replace(/{USERNAME}/g, usuario.nombre);
      htmlMensaje = htmlMensaje.replace(/{EMAIL}/g, usuario.email);
      htmlMensaje = htmlMensaje.replace(/{LINK_RECOVERY}/g, linkRecuperacion);
      generalesHelper.guardarMail(
        "tollray.pms@gmail.com",
        usuario.email,
        "Recuperar contraseña - TollRay",
        htmlMensaje
      );
    });
  });
  res.json({ ok: true });
};

const recoveryPasswordS2 = async (req, res = response) => {
  if (req.query.id == undefined) {
    res.send(
      "Código de recuperación erroneo, este no es el camino que querías"
    );
    return;
  }

  var urlArchivo = "./public/formatos/recuperarClave.html";
  fs.readFile(urlArchivo, "utf8", function (err, data) {
    var html = data;
    if (err) return console.log(err);
    const nombre = fun.decrypt(req.query.id.substring(1));
    try {
      Usuario.findOne({ nombre: nombre }).then((usuario) => {
        console.log(usuario);
        generalesHelper.buscarPreguntasUsuario(
          usuario.id,
          function (preguntas) {
            html = html.replace(/{USERNAME}/g, usuario.nombre);

            html = html.replace(/{PREGUNTA1}/g, preguntas.pregunta1);
            html = html.replace(/{PREGUNTA2}/g, preguntas.pregunta2);
            html = html.replace(/{PREGUNTA3}/g, preguntas.pregunta3);
            html = html.replace(/{PREGUNTA4}/g, preguntas.pregunta4);

            var validar =
              "" +
              '<button id="cmdValidar">Validar Información</button>   ' +
              "<script>                                               " +
              '  $("#cmdValidar").click(function(){                   ' +
              "       $.ajax({                                        " +
              '            method: "POST",                            ' +
              '            contentType: "application/json",           ' +
              '            url: "/pms/recoverPassword2/",             ' +
              "            data: JSON.stringify({                     " +
              '                   id: "' +
              preguntas.id_usuario +
              '", ' +
              '                   a1: $("#txtRespuesta1").val(),      ' +
              '                   a2: $("#txtRespuesta2").val(),      ' +
              '                   a3: $("#txtRespuesta3").val(),      ' +
              '                   a4: $("#txtRespuesta4").val(),})    ' +
              "        })                                             " +
              "            .done(function( msg ) {                    " +
              '               $("#div2").html(msg);                   ' +
              '               $("#div1").hide()                       ' +
              "            });                                        " +
              "       })                                              " +
              "</script>";

            html = html.replace(/{BOTON_RECOVERY}/g, validar);
            res.send(html);
          }
        );
      });
    } catch (e) {
      console.log(e);
    }
  });
};

const validarPreguntas = async (req, res = response) => {
  var id = req.body.id;
  var a1 = req.body.a1;
  var a2 = req.body.a2;
  var a3 = req.body.a3;
  var a4 = req.body.a4;

  generalesHelper.buscarPreguntasUsuario(id, function (preguntas) {
    if (
      preguntas.respuesta1 != a1 ||
      preguntas.respuesta2 != a2 ||
      preguntas.respuesta3 != a3 ||
      preguntas.respuesta4 != a4
    ) {
      res.send("Las respuestas son incorrectas");
    } else {
      var urlArchivo = "./public/formatos/cambiarClave.html";
      fs.readFile(urlArchivo, "utf8", function (err, data) {
        if (err) return console.log(err);
        var html = data;
        html = html.replace(/{ID_USUARIO}/g, fun.encrypt(id));
        res.send(html);
      });
    }
  });
};
const cambiarClave = async (req, res = response) => {
  const id = fun.decrypt(req.body.id);
  const salt = bcrypt.genSaltSync();
  var nuevaClave = bcrypt.hashSync(req.body.txtClave, salt);

  Usuario.findOne({ _id: { $eq: id } }).then((usuario) => {
    usuario.password = nuevaClave;
    usuario.save();
  });

  var urlArchivo = "./public/formatos/claveCambiada.html";
  fs.readFile(urlArchivo, "utf8", function (err, data) {
    res.send("OK" + data);
  });
};

const getPagos = async (req, res = response) => {
  console.log(new Date().toISOString());
  const pagos = await Pago.find({ usuario: { $eq: req.body.uid } }).sort({
    _id: -1,
  });
  // const usuario = await Usuario.findOne({ _id: { $eq: req.body.uid } }).then((usu) => {
  //     pagos.usuario = usu;
  // })
  var resp = { listPagos: pagos };
  console.log(new Date().toISOString());
  res.json(resp);
};

const registrarPago = async (req, res = response) => {
  var d = new Date();
  d.setDate(d.getDate() + 30);

  const pago = new Pago(req.body);
  pago.fecha_fin = d.toISOString();
  await pago.save();
  res.send({
    respuesta: "OK",
    pago: pago,
  });
};

const registrarPreguntas = async (req, res = response) => {
  // console.log(req.body)
  const usuario = await Usuario.findOne({
    _id: { $eq: req.body.uid },
  }).then((usuario) => {
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
    usuario.nuevo = "false";
    usuario.save();
  });
  res.json({
    ok: "MSG102",
    error: "",
  });
};

const report = async (req, res = response) => {
  const usuario = await Usuario.findOne({
    _id: { $eq: req.body.uid },
  }).then((usuario) => {
    generalesHelper.insertReport(
      req.body.tipo,
      req.body.desc,
      req.body.uid,
      null
    );
  });
  res.json({
    ok: "OK",
    error: "",
  });
};

const registerEmailCheck = async (req, res) => {
  try {
    // Debug: Log request details
    console.log('registerEmailCheck - Body:', JSON.stringify(req.body));
    console.log('registerEmailCheck - Body type:', typeof req.body);
    console.log('registerEmailCheck - Content-Type:', req.get('content-type'));
    
    const { email } = req.body || {};
    
    if (!email) {
      console.log('registerEmailCheck - Email missing, body:', req.body);
      return res.status(400).json({
        ok: false,
        error: "Email is required",
      });
    }

    const usuarioDB = await Usuario.findOne({ email });
    if (usuarioDB) {
      return res.json({
        ok: "OK",
        error: "",
      });
    } else {
      return res.json({
        ok: "Not found",
        error: "",
      });
    }
  } catch (error) {
    console.error('Error checking email:', error);
    console.error('Error stack:', error.stack);
    return res.status(500).json({
      ok: false,
      error: "Error checking email",
    });
  }
};

// Add new function for public key endpoint
const obtenerPublicKey = async (req, res = response) => {
  try {
    const { id } = req.params;
    const usuario = await Usuario.findById(id).select('publicKey nombre codigoContacto email');

    if (!usuario) {
      return res.status(404).json({
        ok: false,
        msg: 'Usuario no encontrado',
      });
    }

    res.json({
      ok: true,
      usuario: {
        uid: usuario._id.toString(),
        nombre: usuario.nombre,
        email: usuario.email,
        codigoContacto: usuario.codigoContacto,
        publicKey: usuario.publicKey || null,
      },
    });
  } catch (error) {
    console.error('Error obteniendo public key:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al obtener public key',
    });
  }
};

// Add function to update public key
const actualizarPublicKey = async (req, res = response) => {
  try {
    const { publicKey } = req.body;
    const uid = req.uid;

    if (!publicKey) {
      return res.status(400).json({
        ok: false,
        msg: 'Public key es requerido',
      });
    }

    // Validate public key format
    if (!isValidPublicKey(publicKey)) {
      return res.status(400).json({
        ok: false,
        msg: 'Invalid public key format',
      });
    }

    const usuario = await Usuario.findById(uid);
    if (!usuario) {
      return res.status(404).json({
        ok: false,
        msg: 'Usuario no encontrado',
      });
    }

    usuario.publicKey = publicKey;
    await usuario.save();

    res.json({
      ok: true,
      usuario: {
        ...usuario.toJSON(),
        publicKey: usuario.publicKey,
      },
    });
  } catch (error) {
    console.error('Error actualizando public key:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al actualizar public key',
    });
  }
};

// Add function to update/regenerate encryption keys
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
    try {
      const encryptedPrivateKey = encryptPrivateKey(privateKey, password || usuario.password);
      usuario.encryptedPrivateKey = encryptedPrivateKey;
      console.log('[Usuarios] ✅ Keys updated and encrypted for user:', usuario.email);
    } catch (error) {
      console.error('[Usuarios] ❌ Error encrypting private key:', error);
      return res.status(500).json({
        ok: false,
        msg: 'Error encrypting private key',
      });
    }

    await usuario.save();

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
 * Register/Update FCM Token
 */
const registerFCMToken = async (req, res = response) => {
  try {
    const { fcmToken } = req.body;
    const uid = req.uid; // From JWT middleware
    
    if (!fcmToken || fcmToken.trim() === '') {
      return res.status(400).json({
        ok: false,
        msg: "FCM token is required",
      });
    }
    
    const usuario = await Usuario.findById(uid);
    if (!usuario) {
      return res.status(404).json({
        ok: false,
        msg: "User not found",
      });
    }
    
    usuario.firebaseid = fcmToken.trim();
    await usuario.save();
    
    console.log('[FCM] Token registered for user:', uid);
    
    res.json({
      ok: true,
      msg: "FCM token registered successfully",
    });
  } catch (error) {
    console.error('Error registering FCM token:', error);
    res.status(500).json({
      ok: false,
      msg: "ERR102",
    });
  }
};

module.exports = {
  getUsuarios,
  getUsuario,
  recoveryPasswordS1,
  recoveryPasswordS2,
  updateUsuario,
  validarPreguntas,
  cambiarClave,
  getPagos,
  registrarPago,
  registrarPreguntas,
  report,
  blockUsers,
  unBlockUsers,
  registerEmailCheck,
  obtenerPublicKey,
  actualizarPublicKey,
  actualizarKeys,
  registerFCMToken,
};
