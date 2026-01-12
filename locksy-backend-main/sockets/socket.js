//Instalar libreria node-gcm
// npm install node-gcm --save
const { io } = require("../index");
const Usuario = require("../models/usuario");
const Contacto = require("../models/contacto");
const Grupo = require("../models/grupo");
const GrupoUsuario = require("../models/grupo_usuario");
const Mensaje = require("../models/mensaje");
const Incognito = require("../models/incognito");
// const Solicitud = require('../models/solicitud');

const { comprobarJWT } = require("../helpers/jwt");
const {
  usuarioConectado,
  usuarioDesconectado,
  grabarMensaje,
  saveMsg,
  deleteMessage,
} = require("../controllers/socket");
const { guardarSolicitudEliminarTodos } = require("../controllers/solicitudes");

const contacto = require("../models/contacto");
const mensaje = require("../models/mensaje");
const usuario = require("../models/usuario");
var admin = require("firebase-admin");

// Check if Firebase Admin is already initialized (e.g., in index.js)
// If not, initialize with locksy-app key to match Flutter app
if (!admin.apps.length) {
  var serviceAccount = require("../locksy-app-firebase-adminsdk-fbsvc-d1ddc835d6.json");
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    // other configuration options if needed
  });
  console.log('Firebase Admin: Initialized in sockets/socket.js with locksy-app project');
} else {
  console.log('Firebase Admin: Already initialized (using existing instance)');
}

class MensajePMS {
  constructor(mensaje, usuario) {
    this.mensaje = mensaje;
    this.usuario = usuario;
  }
}

// Mensajes de Sockets
io.on("connection", (client) => {
  const [valido, uid] = comprobarJWT(client.handshake.headers["x-token"]);
  const firebaseid = client.handshake.headers["firebaseid"];
  // Verificar autenticación
  if (!valido) return client.disconnect();
  console.log(uid, "uid");

  // Cliente autenticado
  usuarioConectado(uid, firebaseid);
  client.join(uid);
  client.on("setup", (data) => {
    client.join(data?.codigo);
    io.to(data?.codigo).emit(
      "setup",
      "Hello, you have successfully joined the room " + data?.codigo
    );
  });
  // Handle WebRTC offer
  client.on("offer", async (data) => {
    const { recipientId, sdp, type, codigo, callerId, isVideoCall } = data;
    // Get all users in a room
    const room = io.sockets.adapter.rooms.get(recipientId);
    client.join(recipientId);

    if (room) {
      // List all socket IDs in the room
      console.log(`Users in room ${recipientId}:`, Array.from(room));
    }

    io.to(recipientId).emit("offer", { sdp, type, senderId: client.id });

    const usuario = await Usuario.findOne({ _id: codigo });
    const usuarioMe = await Usuario.findOne({ _id: uid });

    // CRITICAL FIX: FCM data payload values MUST be strings
    // Also sending data-only message for background handling with CallKit
    const message = {
      // Use data-only for better background handling with CallKit
      data: {
        codigo: String(codigo || ''),
        avatar: String(usuarioMe?.avatar || ''),
        nombre: String(usuarioMe?.nombre || 'Incoming Call'),
        callerName: String(usuarioMe?.nombre || 'Incoming Call'),
        callerAvatar: String(usuarioMe?.avatar || ''),
        sdp: String(sdp || ''),
        rtcType: String(type || 'offer'),
        type: "incoming_call",
        callerId: String(callerId || uid || ''),
        isVideoCall: String(isVideoCall === true || isVideoCall === 'true'),
        uuid: String(Date.now()), // Unique call ID
        timestamp: String(Date.now()),
      },
      token: usuario?.firebaseid,
      android: {
        priority: "high",
        ttl: 60000, // 60 seconds TTL for call notifications
      },
      apns: {
        headers: {
          'apns-priority': '10',
          'apns-push-type': 'voip', // VoIP push for iOS
        },
        payload: {
          aps: {
            'content-available': 1,
            sound: 'default',
          },
        },
      },
    };
    if (usuario?.firebaseid) {
      console.log('[Socket] Sending call notification via FCM for offer event');
      admin
        .messaging()
        .send(message)
        .then((response) => {
          console.log("Successfully sent call notification:", response);
        })
        .catch((error) => {
          console.error("Error sending call notification:", error);
        });
    } else {
      console.log('[Socket] No FCM token for recipient, cannot send call notification');
    }
  });
  // Handle WebRTC offer - newOffer sends SDP to recipient via socket
  // FIXED: Use DATA-ONLY FCM to allow custom call UI
  client.on("newOffer", async (data) => {
    const { recipientId, sdp, type, callerId, isVideoCall, roomId } = data;
    console.log("[Socket] newOffer event - sending SDP to recipient:", recipientId);

    // Get caller information to send to recipient
    const caller = await Usuario.findById(callerId);
    const recipient = await Usuario.findById(recipientId);

    // Emit via socket for online users
    io.to(recipientId).emit("newOffer", {
      sdp,
      type,
      recipientId,
      callerId,
      isVideoCall,
      roomId,
      callerName: caller?.nombre || null,
      callerAvatar: caller?.avatar || null,
    });

    // Only send FCM for offline/background users (data-only to avoid auto banners)
    // Skip FCM if user is online - socket event will handle it
    if (recipient?.firebaseid && !recipient.online) {
      const callUUID = roomId || `${Date.now()}-${callerId}-${recipientId}`;
      const callerDisplayName = caller?.nombre || 'Incoming Call';
      const isVideo = isVideoCall === true || isVideoCall === 'true';

      // CRITICAL: DATA-ONLY message (no notification block) - app will show custom call UI
      const message = {
        data: {
          type: "incoming_call",
          recipientId: String(recipientId || ''),
          callerId: String(callerId || ''),
          callerName: String(callerDisplayName),
          callerAvatar: String(caller?.avatar || ''),
          nombre: String(callerDisplayName),
          avatar: String(caller?.avatar || ''),
          isVideoCall: String(isVideo),
          sdp: String(sdp || ''),
          rtcType: String(type || 'offer'),
          uuid: callUUID,
          callId: callUUID,
          timestamp: String(Date.now()),
          callkit_id: callUUID,
          callkit_name_caller: String(callerDisplayName),
          callkit_avatar: String(caller?.avatar || ''),
          callkit_type: String(isVideo ? '1' : '0'),
          callkit_duration: '60000',
          callkit_is_custom_notification: 'true',
          callkit_subtitle: String(isVideo ? 'Incoming Video Call' : 'Incoming Audio Call'),
        },
        token: recipient.firebaseid,
        android: {
          priority: "high",
          ttl: 60000,
          // NO notification block - data-only for custom call UI
        },
        apns: {
          headers: { 'apns-priority': '10', 'apns-push-type': 'voip' },
          payload: {
            aps: {
              sound: 'default',
              'content-available': 1,
              category: 'INCOMING_CALL',
            },
          },
        },
      };

      admin.messaging().send(message)
        .then((response) => console.log("[Socket] ✅ newOffer FCM sent (user offline, DATA-ONLY):", response))
        .catch((error) => console.error("[Socket] ❌ newOffer FCM error:", error.message));
    } else if (recipient?.online) {
      console.log("[Socket] ✅ newOffer: User is online, socket event will handle it");
    }
  });

  // Handle WebRTC offer - startCall triggers FCM notification for background/terminated apps
  // FIXED: Send DATA-ONLY FCM (no notification block) so app can show custom call UI like WhatsApp
  client.on("startCall", async (data) => {
    const { recipientId, callerId, isVideoCall, roomId } = data;
    console.log("[Socket] startCall event received - recipientId:", recipientId, "callerId:", callerId);

    const usuario = await Usuario.findOne({ _id: recipientId });
    const usuarioMe = await Usuario.findOne({ _id: uid || callerId });

    if (!usuario) {
      console.log("[Socket] Recipient user not found:", recipientId);
      return;
    }

    // Generate unique call UUID for CallKit
    const callUUID = roomId || `${Date.now()}-${callerId}-${recipientId}`;

    const callerDisplayName = usuarioMe?.nombre || 'Incoming Call';
    const isVideo = isVideoCall === true || isVideoCall === 'true';

    // CRITICAL: DATA-ONLY message (no notification block) - app will show custom call UI
    // This prevents Android from showing system notification, allowing our custom call UI
    const message = {
      data: {
        type: "incoming_call",
        recipientId: String(recipientId || ''),
        callerId: String(callerId || uid || ''),
        avatar: String(usuarioMe?.avatar || ''),
        callerAvatar: String(usuarioMe?.avatar || ''),
        nombre: String(callerDisplayName),
        callerName: String(callerDisplayName),
        isVideoCall: String(isVideo),
        uuid: callUUID,
        callId: callUUID,
        timestamp: String(Date.now()),
        // Additional fields for notification handling
        callkit_id: callUUID,
        callkit_name_caller: String(callerDisplayName),
        callkit_avatar: String(usuarioMe?.avatar || ''),
        callkit_handle: String(usuarioMe?.email || callerDisplayName),
        callkit_type: String(isVideo ? '1' : '0'),
        callkit_duration: '60000',
        callkit_is_custom_notification: 'true',
        callkit_subtitle: String(isVideo ? 'Incoming Video Call' : 'Incoming Audio Call'),
      },
      token: usuario?.firebaseid,
      android: {
        priority: "high",
        ttl: 60000,
        // NO notification block - data-only for custom call UI
      },
      apns: {
        headers: {
          'apns-priority': '10',
          'apns-push-type': 'voip', // VoIP push for iOS (better for calls)
        },
        payload: {
          aps: {
            'content-available': 1,
            sound: 'default',
            category: 'INCOMING_CALL',
          },
        },
      },
    };

    console.log("[Socket] startCall - recipient firebaseid:", usuario?.firebaseid ? usuario.firebaseid.substring(0, 30) + "..." : "NULL/EMPTY");
    console.log("[Socket] startCall - caller name:", callerDisplayName);
    console.log("[Socket] startCall - isVideoCall:", isVideo);
    console.log("[Socket] startCall - Using DATA-ONLY FCM (no notification block)");

    if (usuario?.firebaseid && usuario.firebaseid.length > 10) {
      console.log("[Socket] Sending startCall FCM notification (DATA-ONLY)...");
      console.log("[Socket] FCM message token:", message.token?.substring(0, 30) + "...");

      admin
        .messaging()
        .send(message)
        .then((response) => {
          console.log("[Socket] ✅ Successfully sent startCall notification (DATA-ONLY):", response);
        })
        .catch((error) => {
          console.error("[Socket] ❌ Error sending startCall notification:");
          console.error("[Socket] Error message:", error.message);
          console.error("[Socket] Error code:", error.code);
          console.error("[Socket] Full error:", JSON.stringify(error, null, 2));
        });
    } else {
      console.log("[Socket] ⚠️ No valid FCM token for recipient:", recipientId);
      console.log("[Socket] ⚠️ firebaseid value:", usuario?.firebaseid || "NULL");
    }
  });

  // Handle WebRTC answer
  client.on("answer", (data) => {
    const { recipientId, sdp, type } = data;
    console.log(`Answer from ${client.id} to ${recipientId}`);
    io.to(recipientId).emit("answer", { sdp, type });
  });

  // CRITICAL: Handle ICE candidates for WebRTC connection
  // Without this handler, WebRTC cannot establish connection and calls stay in "ringing" state
  client.on("candidate", (data) => {
    const { recipientId, candidate, sdpMid, sdpMLineIndex } = data;
    console.log(`[Socket] ICE candidate from ${uid} to ${recipientId}`);
    io.to(recipientId).emit("candidate", { candidate, sdpMid, sdpMLineIndex });
    console.log(`[Socket] ✅ ICE candidate forwarded to ${recipientId}`);
  });
  // Handle WebRTC answer
  client.on("acceptNewCall", (data) => {
    const { recipientId, callerId, isVideoCall } = data;
    console.log(`acceptNewCall `, recipientId, callerId, isVideoCall);
    io.to(callerId).emit("acceptNewCall", {
      recipientId,
      callerId,
      isVideoCall,
    });
  });

  // Handle call-accepted event (new standard event name)
  client.on("call-accepted", (data) => {
    const { callerId, receiverId, roomId, isVideoCall } = data;
    console.log(`[Socket] call-accepted event - callerId: ${callerId}, receiverId: ${receiverId}`);
    // Notify the caller that their call was accepted
    io.to(callerId).emit("call-accepted", {
      callerId,
      receiverId,
      roomId,
      isVideoCall,
    });
    console.log(`[Socket] ✅ call-accepted event forwarded to caller: ${callerId}`);
  });

  client.on("buzz", async (data) => {
    const { recipientId } = data;
    const usuario = await Usuario.findOne({ _id: recipientId });

    const message = {
      notification: {
        title: usuario?.nombre,
        body: "Buzzing....",
      },
      data: {
        type: "buzz",
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
  });

  // Handle end
  client.on("endCall", (data) => {
    const { to, from } = data;
    io.to(to).emit("endCall", { to, from });
  });
  // callCheck
  client.on("callCheck", (data) => {
    const { to, from } = data;

    io.to(to).emit("callCheck", { to, from });
  });
  // socket1
  client.on("socket1", (data) => {
    const { to, from, ...rest } = data;

    io.to(to).emit("socket1", { to, from, data: rest });
  });
  // socket2
  client.on("socket2", (data) => {
    const { to, from, ...rest } = data;

    io.to(to).emit("socket2", { to, from, data: rest });
  });

  // Handle ICE candidates
  client.on("candidate", (data) => {
    const { recipientId, candidate, sdpMid, sdpMLineIndex } = data;
    console.log("candidate", recipientId);

    if (recipientId) {
      io.to(recipientId).emit("candidate", {
        candidate,
        sdpMid,
        sdpMLineIndex,
      });
    } else {
      console.log(`Invalid recipientId for candidate:`, recipientId);
    }
  });

  // Handle hangup
  client.on("hangup", async (data) => {
    const { recipientId, codigo } = data;
    console.log(`Hangup from ${client.id} to ${recipientId}`);
    io.to(recipientId).emit("hangup");
    const usuario = await Usuario.findOne({ codigoContacto: codigo });

    const message = {
      notification: {
        title: "hangup",
        body: "HangedUp",
      },
      data: {
        type: "incoming_callc",
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
  });

  client.on("chat-message", (msg) => {
    io.emit("chat-message", msg);
  });

  // audio start
  // Handle signaling messages
  // client.on("offer", (offer) => {
  //   console.log("Received offer:", offer);
  //   // Forward the offer to the other peer
  //   client.broadcast.emit("offer", offer);
  // });

  // client.on("answer", (answer) => {
  //   console.log("Received answer:", answer);
  //   // Forward the answer to the initiating peer
  //   client.broadcast.emit("answer", answer);
  // });

  // client.on("ice-candidate", (candidate) => {
  //   console.log("Received ICE candidate:", candidate);
  //   // Forward the ICE candidate to the other peer
  //   client.broadcast.emit("ice-candidate", candidate);
  // });
  // audio end
  client.on("message-received-ack", (data) => {
    const messageId = data.messageId;
    const status = data.status;
    const payload = data.payload;

    if (status === "received") {
      console.log(`Message ${messageId} was received by the client.`);

      deleteMessage(payload)
        .then(() => {
          console.log(`Message ${messageId} deleted from the database.`);
        })
        .catch((error) => {
          console.error(`Failed to delete message ${messageId}:`, error);
        });
    }
  });

  client.on("mensaje-personal", async (payload, ack) => {
    const contacto = await Usuario.findById(payload.de);
    const usuario = await Usuario.findById(payload.para);
    console.log("MENSAJE-PERSONAL_Online: " + usuario.online);

    payload.send = true;
    const mensaje = new Mensaje(payload);
    mensaje.usuario = contacto;

    // Emit to socket if user is online
    io.to(payload.para).compress(true).emit("mensaje-personal", mensaje);

    // Always save message to database
    const mensaj1 = await grabarMensaje(payload);

    // Send acknowledgment - support both callback and custom event
    if (ack && typeof ack === 'function') {
      // Standard Socket.IO acknowledgment callback
      ack("RECIBIDO_SERVIDOR");
    }
    // Also send via custom event if ackId is provided (for Dart client compatibility)
    if (payload._ackId) {
      client.emit(`ack_${payload._ackId}`, "RECIBIDO_SERVIDOR");
    }

    // Send push notification only if user is offline or not connected via socket
    // Check if user is in the socket room (connected)
    const room = io.sockets.adapter.rooms.get(payload.para);
    const isUserOnline = room && room.size > 0;

    if (!isUserOnline && usuario?.firebaseid) {
      const message = {
        notification: {
          title: contacto?.nombre || "Mensaje nuevo",
          body: "Mensaje nuevo en Locksy",
        },
        data: {
          type: "message",
          senderId: String(payload.de),
          recipientId: String(payload.para),
          id: String(usuario?._id),
        },
        token: usuario.firebaseid,
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
    }
    // var sender = new gcm.Sender(llaveFirebase);
    // const message = new gcm.Message({
    //     data: {
    //         title: 'Notification Title',
    //         message: 'Notification Message'
    //     }
    // });

    // console.log("MENSAJE-PERSONAL_Onile: " + message);
    // //gcmMessage.addNotification("body", "");
    // sender.send(
    //     message,
    //     { registrationTokens: registrationTokens }
    //     , function (err, response) {
    //         if (err) console.error(err);
    //         // else console.log(response);
    //     });
  });

  client.on("userTyping", async (payload) => {
    io.to(payload.to)
      .compress(true)
      .emit("userTyping", { user: payload.user, typing: true });
    setTimeout(() => {
      // Your code to be executed after 30 seconds goes here
      io.to(payload.to)
        .compress(true)
        .emit("userTyping", { user: payload.user, typing: false });

      console.log("This code runs after 30 seconds");
    }, 3000);
  });

  client.on("mensaje-grupal", async (payload, ack) => {
    const usuario = await Usuario.findById(payload.de);
    const grupo = await Grupo.findOne({ codigo: { $eq: payload.para } });
    Usuario.populate(grupo, {
      path: "usuarioCrea",
      select: ["nombre", "avatar", "codigoContacto"],
    });
    /*
        GrupoUsuario.find(
          {
            grupo: { $eq: grupo._id },
          },
          function (err, grupoUsuarios) {
            Usuario.populate(
              grupoUsuarios,
              { path: "usuarioContacto" },
              function (err, grupoUsuarios) {}
            );
          }
        
    )
    */

    GrupoUsuario.aggregate(
      [
        { $match: { grupo: grupo._id } }, // Match the group by its _id
        {
          $group: {
            _id: "$usuarioContacto", // Group by usuarioContacto to ensure uniqueness
            doc: { $first: "$$ROOT" }, // Take the first occurrence of each unique usuarioContacto
          },
        },
        { $replaceRoot: { newRoot: "$doc" } }, // Replace the root document with the original document (without grouping artifacts)
      ],
      function (err, uniqueGrupoUsuarios) {
        if (err) {
          console.error(err);
          return;
        }

        // Populate the unique usuarioContacto field
        Usuario.populate(
          uniqueGrupoUsuarios,
          { path: "usuarioContacto" },
          function (err, populatedGrupoUsuarios) {
            if (err) {
              console.error(err);
              return;
            }

            console.log(populatedGrupoUsuarios); // Use the populated data
          }
        );
      }
    ).then((gU) => {
      console.log(
        "=============================================length :",
        gU.length
      );

      console.log("=============================================gU :", gU);

      gU.forEach((groupUser, i) => {
        var usua = groupUser.usuarioContacto;
        if (usua != payload.de) {
          Usuario.findById(usua).then(async (usu) => {
            const mensaje = new Mensaje();
            mensaje.grupo = grupo;
            mensaje.de = payload.para;
            mensaje.para = usu._id;
            mensaje.mensaje = payload.mensaje;
            mensaje.send = true;
            mensaje.incognito = false;
            mensaje.usuario = usuario;
            mensaje.reply = payload.reply;
            mensaje.forwarded = payload.forwarded;
            mensaje.parentType = payload.parentType;
            mensaje.parentSender = payload.parentSender;
            mensaje.parentContent = payload.parentContent;

            // DISAPPEARING MESSAGES: Calculate expireAt based on TTL from client
            if (payload.ttl && typeof payload.ttl === 'number' && payload.ttl > 0) {
              mensaje.expireAt = new Date(Date.now() + payload.ttl * 1000);
              console.log(`[GroupMessage] TTL set: ${payload.ttl}s, expires at: ${mensaje.expireAt.toISOString()}`);
            }
            // console.log("==--mensaje--==");
            // console.log(mensaje);
            // console.log("==--mensaje--==**");

            // CRITICAL FIX: Create plain object for socket emission to ensure proper serialization
            // Mongoose documents may not serialize populated fields correctly via Socket.IO
            const socketPayload = {
              grupo: {
                _id: grupo._id,
                codigo: grupo.codigo,
                nombre: grupo.nombre,
                avatar: grupo.avatar,
                descripcion: grupo.descripcion,
                usuarioCrea: grupo.usuarioCrea,
                privateKey: grupo.privateKey,
                publicKey: grupo.publicKey
              },
              usuario: {
                _id: usuario._id,
                uid: usuario.uid,
                nombre: usuario.nombre,
                avatar: usuario.avatar,
                email: usuario.email
              },
              de: payload.para, // group code
              para: usu._id,   // recipient user ID
              mensaje: payload.mensaje,
              send: true,
              incognito: false,
              reply: payload.reply,
              forwarded: payload.forwarded,
              parentType: payload.parentType,
              parentSender: payload.parentSender,
              parentContent: payload.parentContent,
              createdAt: new Date(),
              updatedAt: new Date()
            };

            io.to(mensaje.para).compress(true).emit("mensaje-grupal", socketPayload);
            mensaje.send = true;
            //  mensaje.save();
            const mensaj1 = await saveMsg(mensaje);
            // console.log(usu.nombre + ":: " + mensaje.para + " ONLINE: " + usu.online)
            // console.log(mensaje.mensaje.content)

            // Send acknowledgment - support both callback and custom event
            if (ack && typeof ack === 'function') {
              // Standard Socket.IO acknowledgment callback
              ack("RECIBIDO_SERVIDOR");
            }
            // Also send via custom event if ackId is provided (for Dart client compatibility)
            if (payload._ackId) {
              client.emit(`ack_${payload._ackId}`, "RECIBIDO_SERVIDOR");
            }
            var registrationTokens = [];
            registrationTokens.push(usu.firebaseid);

            const message = {
              notification: {
                title: "Mensaje nuevo",
                body: "Mensaje nuevo en Locksy",
              },
              token: usu.firebaseid,
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

            // var sender = new gcm.Sender(llaveFirebase);
            // var gcmMessage = new gcm.Message();

            // gcmMessage.addNotification("title", "Mensaje nuevo en Tollray");
            // //gcmMessage.addNotification("body", "");
            // sender.send(
            //     gcmMessage,
            //     { registrationTokens: registrationTokens }
            //     , function (err, response) {
            //         if (err) console.error(err);
            //         // else console.log(response);
            //     });
          });
        }
      });
    });
  });

  client.on("recibido-cliente", async (payload, ack) => {
    // console.log("==recibido-cliente==");
    // console.log(payload);
    io.to(payload.para).emit("recibido-cliente", payload);
  });

  client.on("modo-incognito", async (payload) => {
    var msj = payload;

    const usuario = await Usuario.findById(payload.para);
    if (usuario.online || !usuario.online) {
      io.to(payload.para).emit("modo-incognito", msj);
    } else {
      const incognito = new Incognito(msj);
      incognito.save();
    }
  });

  client.on("llamada", async (payload) => {
    const usuario = await Usuario.findById(payload.para);
    const caller = await Usuario.findById(payload.de || uid);

    if (usuario.online) payload.send = true;
    else payload.send = false;

    const mensaje = await grabarMensaje(payload, false);
    io.to(payload.para).emit("llamada", mensaje);

    // Only send FCM for offline/background users (data-only to avoid auto banners)
    // Skip FCM if user is online - socket event will handle it
    if (usuario?.firebaseid && !usuario.online) {
      const callUUID = `${Date.now()}-${payload.de || uid}-${payload.para}`;
      const callerDisplayName = caller?.nombre || 'Incoming Call';
      const isVideo = payload.isVideoCall === true || payload.isVideoCall === 'true';

      const message = {
        // DATA-ONLY payload to prevent Android auto-notification; client will show rich notification
        data: {
          type: "incoming_call",
          callerId: String(payload.de || uid || ''),
          recipientId: String(payload.para || ''),
          callerName: String(callerDisplayName),
          callerAvatar: String(caller?.avatar || ''),
          nombre: String(callerDisplayName),
          avatar: String(caller?.avatar || ''),
          isVideoCall: String(isVideo),
          uuid: callUUID,
          timestamp: String(Date.now()),
          callkit_id: callUUID,
          callkit_name_caller: String(callerDisplayName),
          callkit_avatar: String(caller?.avatar || ''),
          callkit_type: String(isVideo ? '1' : '0'),
          callkit_is_custom_notification: 'true',
          callkit_subtitle: isVideo ? 'Video Call' : 'Audio Call',
        },
        token: usuario.firebaseid,
        android: {
          priority: "high",
          ttl: 60000,
        },
        apns: {
          headers: { 'apns-priority': '10', 'apns-push-type': 'voip' },
          payload: {
            aps: {
              sound: 'default',
              'content-available': 1,
              category: 'INCOMING_CALL',
            },
          },
        },
      };

      admin.messaging().send(message)
        .then((response) => console.log("[Socket] ✅ llamada FCM sent (user offline):", response))
        .catch((error) => console.error("[Socket] ❌ llamada FCM error:", error.message));
    } else if (usuario?.online) {
      console.log("[Socket] ⚠️ llamada: User is online, skipping FCM (socket will handle it)");
    }
  });

  client.on("rechazar-llamada", async (payload) => {
    const usuario = await Usuario.findById(payload.para);
    if (usuario.online) payload.send = true;
    else payload.send = false;

    const mensaje = await grabarMensaje(payload, false);
    io.to(payload.para).emit("rechazar-llamada", mensaje);
  });

  client.on("llamada-terminada", async (payload) => {
    const usuario = await Usuario.findById(payload.para);
    if (usuario.online) payload.send = true;
    else payload.send = false;

    const mensaje = await grabarMensaje(payload, false);
    io.to(payload.para).emit("llamada-terminada", mensaje);

    var registrationTokens = [];
    registrationTokens.push(usuario.firebaseid);
    const message = {
      notification: {
        title: "Llamada finalizada ",
        body: "Llamada finalizada en Locksy",
      },
      token: usuario.firebaseid,
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

    //Enviar notificacion push
    // var sender = new gcm.Sender(llaveFirebase);
    // var gcmMessage = new gcm.Message();
    // var registrationTokens = [];
    // registrationTokens.push(usuario.firebaseid);

    // gcmMessage.addNotification("title", "Llamada finalizada en Tollray");
    // sender.send(
    //     gcmMessage, {
    //     registrationTokens: registrationTokens
    // }, function (err, response) {
    //     if (err) console.error(err);
    //     else console.log(response);
    // });
  });

  client.on("disconnect", async () => {
    const usuario = await Usuario.findById(uid);
    console.log("USUARIO OFFLINE: " + new Date().toISOString(), usuario.nombre);
    await usuarioDesconectado(uid);

    console.log(`User disconnected: ${client?.id}`);
  });

  client.on("mensaje", async (payload) => {
    console.log("Mensaje", payload);
    await io.emit("mensaje", { admin: "Nuevo mensaje" });
  });

  client.on("eliminar-para-todos", async (payload) => {
    const contacto = await Usuario.findById(payload.de);
    const usuario = await Usuario.findById(payload.para);
    console.log(payload);
    if (usuario.online)
      io.to(payload.para).emit("eliminar-para-todos", payload);
    else await guardarSolicitudEliminarTodos(payload);
  });
});
module.exports = { io, admin };
