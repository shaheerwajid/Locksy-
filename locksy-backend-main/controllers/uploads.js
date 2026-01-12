var urlFiles = "./uploads/";
var express = require("express");
var multer = require("multer"),
  upload = multer({ dest: urlFiles });
var fs = require("fs");
// var gcm = require("node-gcm");

const { io } = require("../index");
const Mensaje = require("../models/mensaje");
const Usuario = require("../models/usuario");
const Grupo = require("../models/grupo");
const GrupoUsuario = require("../models/grupo_usuario");

var admin = require("firebase-admin");

var serviceAccount = require("../locksy-app-firebase-adminsdk-fbsvc-d1ddc835d6.json");

const { grabarMensaje } = require("../controllers/socket");

const subirArchivos = async (req, res, next) => {
  console.log("==SUBIR ARCHIVO==");
  const body = req.body;
  const archivos = req.files;
  var grupo;
  var receptores = [];
  console.log("==SUBIR ARCHIVO - Body received==", JSON.stringify(body));
  console.log("==grupo type check==", {
    type: typeof body.grupo,
    isString: typeof body.grupo === 'string',
    keys: body.grupo ? Object.keys(body.grupo) : 'null'
  });

  // FIX: Correctly check if it's NOT a group (missing or empty object)
  // If it's a string (group code), it IS a group, so we want to go to ELSE
  if (!body.grupo || (typeof body.grupo === 'object' && Object.keys(body.grupo).length === 0)) {
    console.log("==Processing as Personal Message==");
    receptores.push(body.para);
  } else {
    console.log("==Processing as Group Message==");
    grupo = await Grupo.findOne({ codigo: { $eq: body.para } });
    if (grupo) {
      await Usuario.populate(grupo, {
        path: "usuarioCrea",
        select: ["nombre", "avatar", "codigoContacto"],
      });

      // FIX: Properly await the group users query
      const grupoUsuarios = await GrupoUsuario.find({
        grupo: { $eq: grupo._id },
      });

      await Usuario.populate(grupoUsuarios, {
        path: "usuarioContacto"
      });

      console.log("==Group users found==", grupoUsuarios.length);
      grupoUsuarios.forEach((groupUser) => {
        var usua = groupUser.usuarioContacto;
        // FIX: usua is a populated User object, use ._id for comparison and storage
        var usuaId = usua?._id?.toString() || usua?.toString();
        console.log("==Checking group user==", { usuaId, senderDe: body.de, isMatch: body.de === usuaId });
        if (body.de !== usuaId && usuaId) {
          receptores.push(usuaId);
          console.log("==Added receptor==", usuaId);
        }
      });
    }
  }

  if (!archivos) {
    const error = new Error("Please upload a file");
    error.httpStatusCode = 400;
    return next("hey error");
  } else {
    var emisor = await Usuario.findById(body.de);
    var listaMensajes = [];
    // Use Promise.all to wait for all async operations
    const savePromises = [];

    for (let i = 0; i < receptores.length; i++) {
      var recipt = receptores[i];
      for (let index = 0; index < archivos.length; index++) {
        var fileToSend = archivos[index];
        if (fileToSend != null) {
          const mensaje = new Mensaje({
            de: body.de,
            para: recipt,
            usuario: emisor,
            mensaje: {
              extension: body.extension,
              fecha: body.fecha,
              type: body.type,
              content: fileToSend.path,
            },
            forwarded: body.forwarded,
          });
          mensaje.grupo = grupo;

          // DISAPPEARING MESSAGES: Calculate expireAt based on TTL from client
          if (body.ttl && typeof Number(body.ttl) === 'number' && Number(body.ttl) > 0) {
            mensaje.expireAt = new Date(Date.now() + Number(body.ttl) * 1000);
            console.log(`[Upload] TTL set: ${body.ttl}s, expires at: ${mensaje.expireAt.toISOString()}`);
          }

          console.log("==Setting message group==", grupo ? grupo._id : "GRUPO IS NULL");

          var receptor = await Usuario.findById(recipt);

          // CRITICAL FIX: Await the save operation
          const savePromise = mensaje.save().then((savedDoc) => {
            // Convert to plain object to ensure we can modify fields freely for emission
            let savedMensaje = savedDoc.toObject();

            // Emit socket event after save completes
            const isGroupMsg = !body.grupo || (typeof body.grupo === 'object' && Object.keys(body.grupo).length === 0) ? false : true;

            console.log("==Message saved, emitting socket event==", {
              para: savedMensaje.para,
              isGroup: isGroupMsg,
              messageId: savedMensaje._id,
              msgGrupoField: savedMensaje.grupo
            });

            if (!isGroupMsg) {
              console.log("==Emitting mensaje-personal to==", savedMensaje.para);
              io.to(savedMensaje.para)
                .compress(true)
                .emit("mensaje-personal", savedMensaje);
            } else {
              savedMensaje.de = body.para; // Set sender as group code
              // FORCE overwrite grupo with the full object to ensure frontend gets privateKey etc.
              if (grupo) {
                savedMensaje.grupo = grupo;
              }
              console.log("==Emitting mensaje-grupal to==", {
                para: savedMensaje.para,
                grupoInPayload: savedMensaje.grupo ? 'Present (Object)' : 'NULL'
              });
              io.to(savedMensaje.para).compress(true).emit("mensaje-grupal", savedMensaje);
            }

            // Send Firebase notification (fire-and-forget, but don't block)
            const message = {
              notification: {
                title: "Mensaje nuevo",
                body: "Mensaje nuevo en CryptoChat",
              },
              token: receptor.firebaseid,
              android: {
                priority: "high",
              },
            };

            admin
              .messaging()
              .send(message)
              .then((response) => {
                console.log("Successfully sent notification:", response);
              })
              .catch((error) => {
                console.error("Error sending notification:", error);
              });

            return savedMensaje;
          }).catch((error) => {
            console.error("Error saving mensaje:", error);
            throw error;
          });

          savePromises.push(savePromise);

          // var registrationTokens = [];
          // registrationTokens.push(receptor.firebaseid);
          // var gcmMessage = new gcm.Message();
          // gcmMessage.addData("title", "Mensaje nuevo en Tollray");
          // //gcmMessage.addNotification("title", "Mensaje nuevo en Tollray");

          // var sender = new gcm.Sender(llaveFirebase);
          // sender.send(
          //     gcmMessage,
          //     { registrationTokens: registrationTokens }
          //     , function (err, response) {
          //         if (err) console.error(err);
          //         // else console.log(response);
          //     });
        }
      }
    }

    // CRITICAL FIX: Wait for all saves to complete before sending response
    try {
      await Promise.all(savePromises);
      if (!emisor.online && listaMensajes.length > 0) {
        await Mensaje.insertMany(listaMensajes);
      }
      console.log("==FIN SUBIR ARCHIVO==");

      // Extract filenames for response
      const filenames = archivos.map(file => file.filename);

      res.json({
        ok: true,
        filenames: filenames, // Return the uploaded filenames (hashes)
      });
    } catch (error) {
      console.error("Error in subirArchivos:", error);
      res.status(500).json({
        ok: false,
        msg: "Error al guardar mensajes"
      });
    }
  }
};

const uploadFiles = async (req, res) => {
  var response = await dynamicUploadFile(req.body, req.body.type);
  var resp = "error";
  if (response) {
    resp = "ok";
  } else {
    resp = "error";
  }
  console.log(resp);
  res.json(resp);
};

const dynamicUploadFile = async (body, type) => {
  var contacto = await Usuario.findById(body.de);
  var listaContactos = [];
  // for (let index = 0; index < body[type].length; index++) {
  for (let index = 0; index < body.documents.length; index++) {
    var archivo = body.documents[index].fileEncode;
    const payload = {
      de: body.de,
      para: body.para,
      mensaje: {
        extension: body.documents[index].extension,
        fecha: body.documents[index].fecha,
        type: body.documents[index].type,
        content: archivo,
      },
      usuario: contacto,
    };
    const mensaje = new Mensaje(payload);
    if (!contacto.online) {
      listaContactos.push(contacto);
    }
    console.log("EMITIENDO ARCHIVO: " + contacto.nombre);
    // console.log(mensaje)
    const mensaj1 = await grabarMensaje(mensaje);

    io.to(mensaje.para).compress(true).emit("mensaje-personal", mensaje);
  }
  if (!contacto.online) {
    Mensaje.insertMany(listaContactos);
  }
  return true;
};

const getavatars = async (req, res) => {
  const folder = "./public/avatars/";
  var listaAvatars = [];
  fs.readdir(folder, (err, files) => {
    files.forEach((file) => {
      listaAvatars.push(file);
      //console.log(file);
    });
    res.json(listaAvatars);
  });
};

const getgruposimg = async (req, res) => {
  const folder = "./public/gruposImg/";
  var listaAvatars = [];
  fs.readdir(folder, (err, files) => {
    files.forEach((file) => {
      listaAvatars.push(file);
      //console.log(file);
    });
    res.json(listaAvatars);
  });
};

const getFile = async (req, res) => {
  res.send(urlFiles + req.query.f);
};

module.exports = {
  uploadFiles,
  getavatars,
  getgruposimg,
  subirArchivos,
  getFile,
};
