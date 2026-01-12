const { response } = require("express");
const Contacto = require("../models/contacto");
const Usuario = require("../models/usuario");
const { io, admin } = require("../sockets/socket");

const sendFirebaseNotification = (usuario, title, body) => {
  const message = {
    notification: {
      title: title,
      body: body,
    },
    data: {
      type: "contact",
    },

    token: usuario?.firebaseid,
    android: {
      priority: "high",
    },
  };
  if (usuario?.firebaseid) {
    admin
      .messaging()
      .send(message)
      .then((response) => {
        console.log("Successfully sent notification:", response);
      })
      .catch((error) => {
        console.error("Error sending notification:", error);
      });
  }
};
const createContacto = async (req, res = response) => {
  //console.log(req.connection.remoteAddress)

  try {
    const usuarioUsuario = await Usuario.findOne({
      codigoContacto: req.body.codigoUsuario,
    });
    const usuarioContacto = await Usuario.findOne({
      codigoContacto: req.body.codigoContacto,
    });

    sendFirebaseNotification(
      usuarioContacto,
      "Contact request",
      "You have received a contact request"
    );
    console.log(req.body);
    const contacto = new Contacto({
      fecha: req.body.fecha,
      activo: req.body.activo,
      fechausuario: req.body.fechausuario,
      usuario: usuarioUsuario._id,
      contacto: usuarioContacto._id,
      publicKey: usuarioContacto.publicKey,
    });
    const existeContacto = await Contacto.findOne({
      usuario: usuarioUsuario._id,
      contacto: usuarioUsuario._id,
    });
    if (existeContacto) {
      return res.status(400).json({
        ok: false,
        msg:
          existeContacto.activo == "1"
            ? "El Contacto ya ha sido registrado"
            : "Ya existe una solicitud pendiente",
      });
    }
    await contacto.save();

    // Queue notification (async, don't block)
    try {
      const { queueNotification } = require('../services/notification/producer');
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
      const feedGenerator = require('../services/feed/generator');
      await feedGenerator.triggerFeedGeneration('contact', {
        usuario: usuarioUsuario._id.toString(),
        contacto: usuarioContacto._id.toString()
      }).catch(err => console.error('Feed generation error:', err));
    } catch (error) {
      console.error('Error triggering feed generation:', error);
    }

    res.json({
      ok: true,
      contacto,
    });
  } catch (e) {
    console.log(e);
  }
};

//Obtener Contactos
const getContactos = async (req, res = response) => {
  // Get current user from token (req.uid is set by JWT middleware)
  const currentUser = await Usuario.findById(req.uid);
  
  if (!currentUser) {
    return res.status(404).json({
      ok: false,
      msg: "Current user not found"
    });
  }
  
  // If code is provided, find that user, otherwise use current user
  let usuarioUsuario = currentUser;
  if (req.body.code) {
    usuarioUsuario = await Usuario.findOne({
      codigoContacto: req.body.code,
    });
    if (!usuarioUsuario) {
      return res.status(404).json({
        ok: false,
        msg: "User not found with provided code"
      });
    }
  }
  
  const activo = req.body.activo !== undefined ? req.body.activo : "1";
  
  Contacto.find(
    {
      activo: { $eq: activo },
      contacto: { $eq: usuarioUsuario._id },
    },
    function (err, solicitudes) {
      Usuario.populate(
        solicitudes,
        { path: "usuario" },
        function (err, solicitudes) {}
      );
      Usuario.populate(
        solicitudes,
        { path: "contacto" },
        function (err, solicitudes) {
          res.json({ solicitudes });
        }
      );
    }
  );
};

const getListadoContactos = async (req, res = response) => {
  // Get current user from token (req.uid is set by JWT middleware)
  const currentUser = await Usuario.findById(req.uid);
  
  if (!currentUser) {
    return res.status(404).json({
      ok: false,
      msg: "Current user not found"
    });
  }
  
  // If code is provided, find that user, otherwise use current user
  var usuario = currentUser;
  if (req.body.code) {
    usuario = await Usuario.findOne({ codigoContacto: req.body.code });
    if (!usuario) {
      return res.status(404).json({
        ok: false,
        msg: "User not found with provided code"
      });
    }
  }

  let blockUsers = usuario?.blockUsers ? usuario.blockUsers.map((id) => id) : [];
  var listContactos;
  Contacto.find(
    {
      $and: [
        {
          activo: "1",
          $or: [{ contacto: { $eq: usuario } }, { usuario: { $eq: usuario } }],
        },
        {
          contacto: { $nin: blockUsers }, // Ensure `contacto` is not in `blockUsers`
          usuario: { $nin: blockUsers }, // Ensure `contacto` is not in `blockUsers`
        },
      ],
    },
    function (err, listContactos) {
      Usuario.populate(
        listContactos,
        { path: "usuario" },
        function (err, listContactos) {}
      );
      Usuario.populate(
        listContactos,
        { path: "contacto" },
        function (err, listContactos) {
          if (err) {
            return res.status(500).json({
              ok: false,
              msg: "Error populating contacts",
            });
          }

          const sanitized = listContactos.filter(
            (contacto) => contacto.usuario && contacto.contacto
          );
          if (sanitized.length !== listContactos.length) {
            console.warn(
              `[getListadoContactos] Filtered ${
                listContactos.length - sanitized.length
              } invalid contacto entries for user ${usuario._id}`
            );
          }

          res.json({ listContactos: sanitized });
        }
      );
    }
  );
};

// Activar Solicitud
const activateContacto = async (req, res = response) => {
  try {
    const usuarioUsuario = await Usuario.findOne({
      codigoContacto: req.body.codigoUsuario,
    });
    const usuarioContacto = await Usuario.findOne({
      codigoContacto: req.body.codigoContacto,
    });

    if (!usuarioUsuario) {
      return res.status(404).json({
        ok: false,
        msg: 'Usuario no encontrado'
      });
    }

    if (!usuarioContacto) {
      return res.status(404).json({
        ok: false,
        msg: 'Contacto no encontrado'
      });
    }

    sendFirebaseNotification(
      usuarioUsuario,
      "Contact request accepted",
      "Your contact request has been accepted."
    );

    const contacto = await Contacto.findOne({
      usuario: usuarioUsuario._id,
      contacto: usuarioContacto._id,
    });

  if (!contacto) {
    return res.status(404).json({
      ok: false,
      msg: 'Contacto no encontrado'
    });
  }

  contacto.activo = "1";
  await contacto.save();

  // Queue notification (async, don't block)
  try {
    const { queueNotification } = require('../services/notification/producer');
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
      const feedGenerator = require('../services/feed/generator');
      await feedGenerator.triggerFeedGeneration('contact', {
        usuario: usuarioUsuario._id.toString(),
        contacto: usuarioContacto._id.toString()
      }).catch(err => console.error('Feed generation error:', err));
    } catch (error) {
      console.error('Error triggering feed generation:', error);
    }

    res.json({
      ok: true,
    });
  } catch (error) {
    console.error('Error activating contacto:', error);
    return res.status(500).json({
      ok: false,
      msg: 'Error al activar contacto'
    });
  }
};
const updatContactDisappearTime = async (req, res = response) => {
  if (
    !req.body.disappearMessageSetAt ||
    !req.body.disappearMessageTime ||
    (!req.body.contacto && !req.body.usuario)
  ) {
    res.status(400).json({ ok: false, message: "Missing properties" });
    return;
  }
  const contacto = await Contacto.findOne({
    contacto: req.body.contacto,
    usuario: req.body.usuario,
  });
  if (contacto) {
    contacto.disappearMessageSetAt = new Date(req.body.disappearMessageSetAt);
    contacto.disappearMessageTime = req.body.disappearMessageTime;
    contacto.disappearedCheck = true;
    contacto.save();
  } else {
    return res.json({
      ok: false,
      message: "No contact found",
    });
  }

  res.json({
    ok: true,
  });
};
const rejectCallHandler = async (req, res = response) => {
  console.log(req.body, "req.body");
  io.to(req.body.callerId).emit("rejectCall", { data: "rejected" });
  res.json({
    ok: true,
  });
};

// Eliminar Solicitud
const dropContacto = async (req, res = response) => {
  const usuarioUsuario = await Usuario.findOne({
    codigoContacto: req.body.codigoUsuario,
  });
  const usuarioContacto = await Usuario.findOne({
    codigoContacto: req.body.codigoContacto,
  });

  // const contacto = await Contacto.findOne({
  //     $or: [{
  //         $and: [
  //             { usuario: { $eq: usuarioUsuario._id } },
  //             { contacto: { $eq: usuarioContacto._id } },
  //         ],
  //         $and: [
  //             { usuario: { $eq: usuarioContacto._id } },
  //             { contacto: { $eq: usuarioUsuario._id } },
  //         ]
  //     }]
  // }).then((contacto) => {
  //     try {
  //         contacto.remove();
  //     } catch (e) {
  //         console.log(e);
  //     }
  // });

  const contacto = await Contacto.findOne({
    $and: [
      { usuario: { $eq: usuarioUsuario._id } },
      { contacto: { $eq: usuarioContacto._id } },
    ],
  }).then((contacto) => {
    if (contacto == null) {
      contacto = Contacto.findOne({
        $and: [
          { contacto: { $eq: usuarioUsuario._id } },
          { usuario: { $eq: usuarioContacto._id } },
        ],
      }).then((contacto) => {
        console.log("==ELIMINA CONTACTO 2==");
        console.log(contacto);
        try {
          contacto.remove();
        } catch (e) {
          console.log(e);
        }
      });
    } else {
      console.log("==ELIMINA CONTACTO 1==");
      console.log(contacto);
      try {
        contacto.remove();
      } catch (e) {
        console.log(e);
      }
    }
  });

  res.json({
    ok: true,
  });
  console.log("===respuesta===");
  console.log(res.body);
};

module.exports = {
  createContacto,
  getContactos,
  getListadoContactos,
  activateContacto,
  dropContacto,
  updatContactDisappearTime,
  rejectCallHandler,
};
