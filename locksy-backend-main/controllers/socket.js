const Usuario = require("../models/usuario");
const Grupo = require("../models/grupo");

const Mensaje = require("../models/mensaje");
const { io } = require("../index");
const Incognito = require("../models/incognito");
const Contacto = require("../models/contacto");

const usuarioConectado = async (uid = "", firebaseid) => {
  const usuario = await Usuario.findById(uid);

  console.log("USUARIO ONLINE: " + new Date().toISOString(), usuario?.nombre);

  // Set user as online when socket connects
  usuario.online = true;
  usuario.lastSeen = new Date();

  // Save FCM token from socket connection
  if (firebaseid && firebaseid.trim() !== '') {
    usuario.firebaseid = firebaseid.trim();
    console.log('[Socket] ✅ FCM token saved from socket connection for user:', uid);
  } else {
    console.log('[Socket] ⚠️ No FCM token in socket connection for user:', uid);
  }

  await usuario.save();

  Contacto.find(
    {
      $or: [{ usuario: uid }, { contacto: uid }],
    },
    function (err, contatcts) {
      if (contatcts?.length > 0) {
        contatcts.forEach((contact) => {
          if (contact.usuario == uid) {
            io.to(contact.contacto).emit("userConnection", {
              connected: true,
              user: uid,
            });
          } else {
            io.to(contact.usuario).emit("userConnection", {
              connected: true,
              user: uid,
            });
          }
        });
      }
    }
  );

  Incognito.find(
    {
      para: usuario._id,
    },
    function (err, incognitos) {
      incognitos.forEach((incognito) => {
        io.to(incognito.para).emit("modo-incognito", incognito);
        incognito.remove();
      });
    }
  );

  /*
        Mensaje.find({
            para: usuario._id
        }, function (err, mensajes) {
    
      console.log("============================ Connection ✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅, msgs ",mensajes.length);
    
            Usuario.populate(mensajes, { path: "usuario" }, function (err, mensajes) {
                mensajes.forEach(mensaje => {
                    if (mensaje.grupo == null)
                        io.to(mensaje.para).emit('mensaje-personal', mensaje);
                   // else
                   //     io.to(mensaje.para).emit('mensaje-grupal', mensaje);
    
    
     else{
                        Grupo.populate(mensajes, { path: "grupo" }, function (err, mensajes) {
                        io.to(mensaje.para).emit('mensaje-grupal', mensaje);
                    });
                    }
    
                    console.log(mensaje)
                    mensaje.remove();
                })
            })
        });
    
    */

  Mensaje.find({ para: usuario._id }, function (err, mensajes) {
    if (err) {
      console.error("Error fetching messages:", err);
      return;
    }

    console.log(
      "============================ Connection ✅, msgs:",
      mensajes.length
    );

    // Populate the 'usuario' field in the retrieved messages
    Usuario.populate(
      mensajes,
      { path: "usuario" },
      function (err, mensajesPopulated) {
        if (err) {
          console.error("Error populating usuario:", err);
          return;
        }

        mensajesPopulated.forEach((mensaje) => {
          if (mensaje.grupo == null) {
            // Emit personal message
            io.to(mensaje.para).emit("mensaje-personal", mensaje);
          } else {
            // Populate the 'grupo' field and then emit group message
            Grupo.populate(
              mensaje,
              { path: "grupo", populate: { path: "usuarioCrea" } },
              function (err, mensajeGrupal) {
                if (err) {
                  console.error("Error populating grupo:", err);
                  return;
                }
                io.to(mensaje.para).emit("mensaje-grupal", mensajeGrupal);
              }
            );
          }

          // Log the message
          // console.log(mensaje);
        });
      }
    );
  });

  return usuario;
};

const getContacto = (mensaje) => {
  var contacto = Usuario.findById(mensaje.de);
  return contacto;
};

const usuarioDesconectado = async (uid = "") => {
  const usuario = await Usuario.findById(uid);
  usuario.lastSeen = new Date().toISOString();
  usuario.online = false;
  await usuario.save();
  Contacto.find(
    {
      $or: [{ usuario: uid }, { contacto: uid }],
    },
    function (err, contatcts) {
      if (contatcts?.length === 0) return;
      contatcts.forEach((contact) => {
        if (contact.usuario == uid) {
          io.to(contact.contacto).emit("userDesConnection", {
            connected: false,
            user: uid,
            lastConnection: new Date().toISOString(),
          });
        } else {
          io.to(contact.usuario).emit("userDesConnection", {
            connected: false,
            user: uid,
            lastConnection: new Date().toISOString(),
          });
        }
      });
    }
  );
  return usuario;
};

const grabarMensaje = async (payload, guardar = true) => {
  try {
    const mensaje = new Mensaje(payload);
    mensaje.usuario = mensaje.de;

    // DISAPPEARING MESSAGES: Calculate expireAt based on TTL from client
    // ttl is expected in seconds from the client
    if (payload.ttl && typeof payload.ttl === 'number' && payload.ttl > 0) {
      mensaje.expireAt = new Date(Date.now() + payload.ttl * 1000);
      console.log(`[Message] TTL set: ${payload.ttl}s, expires at: ${mensaje.expireAt.toISOString()}`);
    }

    if (guardar) await mensaje.save();

    console.log("✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅");

    // console.log('mensaje11111111111111111111111 ================>',mensaje);
    //      console.log('mensaje22222222222222222222222222222222222 ================>', mensaje.mensaje);

    console.log("Message Saved  ✅✅✅✅✅✅✅✅✅✅✅✅");
    console.log("Message. Saved");

    return mensaje;
  } catch (error) {
    return false;
  }
};

const deleteMessage = async (mensaje, guardar = true) => {
  try {
    //console.log('mensaje3333333333333 ================>',mensaje);
    //    console.log('mensaje3333333333333 ================>', mensaje.mensaje);
    //      console.log('mensaje3333333333333 ================>', mensaje.mensaje.content);

    // Find the message using await instead of a callback
    //        const mensajes = await Mensaje.findOne({ mensaje: mensaje.mensaje, para: mensaje.para });

    const mensajeObj = JSON.parse(mensaje.mensaje);
    // Access 'content' field
    const mensajeContent = mensajeObj.content;
    const mensajeFecha = mensajeObj.fecha;
    // console.log('mensa44444444444444444444444444 ================>', mensajeContent);

    // Find the message using await instead of a callback
    const mensajes = await Mensaje.findOne({
      "mensaje.content": mensajeContent, // Match the 'content' field in 'mensaje'
      "mensaje.fecha": mensajeFecha, // Match the 'fecha' field in 'mensaje'
      para: mensaje.para, // Match the 'para' field
    });

    if (mensajes) {
      // Remove the message if found
      //        console.log('Remove the message if found Found !!!!!!!!!');
      await mensajes.remove();
      console.log("✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅");
      console.log("Message Found  ✅✅✅✅✅✅✅✅✅✅✅✅");
      //      console.log('Remove the message if found Removed !!!!!!!!!');
      //    console.log('Remove the message if found Removed !!!!!!!!!');
      return true; // Return true if deletion was successful
    } else {
      console.log("❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌");
      console.log("Message Not Found ❌");
      //            console.log(' Nooooooooooot Found !!!!!!!!!');
      //          console.log('Remove the message if found Nooooooooooot Found !!!!!!!!!');
      return false; // Return false if no message was found
    }
  } catch (error) {
    console.error("Error deleting message:", error);
    return false; // Return false in case of any error
  }
};

const saveMsg = async (mensaje, guardar = true) => {
  try {
    if (guardar) await mensaje.save();

    console.log("✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅");

    //        console.log('mensaje11111111111111111111111 ================>',mensaje);
    //      console.log('mensaje22222222222222222222222222222222222 ================>', mensaje.mensaje);
    console.log("Message Saved  ✅✅✅✅✅✅✅✅✅✅✅✅");
    console.log("Message. Saved");
    return mensaje;
  } catch (error) {
    console.log("❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌");
    console.log("Message Not Saved ❌", error);
    return false;
  }
};

module.exports = {
  usuarioConectado,
  usuarioDesconectado,
  grabarMensaje,
  deleteMessage,
  saveMsg,
};
