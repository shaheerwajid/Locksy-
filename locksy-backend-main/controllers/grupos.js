const { response } = require("express");
const { io } = require("../index");

const Grupo = require("../models/grupo");
const GrupoUsuario = require("../models/grupo_usuario");
const Usuario = require("../models/usuario");
const Solicitud = require("../models/solicitud");

/**
 * Miembros de un grupo
 * @author Deyner Reinoso
 */
const groupMembers = async (req, res = response) => {
  try {
    var codigoGrupo = req.body.codigo;
    if (!codigoGrupo) {
      return res.status(400).json({
        ok: false,
        msg: 'Código de grupo es requerido'
      });
    }

    var grupo = await Grupo.findOne({ codigo: codigoGrupo });
    if (!grupo) {
      return res.status(404).json({
        ok: false,
        msg: 'Grupo no encontrado'
      });
    }

    var usuariosGrupo = await GrupoUsuario.find({ grupo: { $eq: grupo } });
    const listaUsuariosGrupo = await Usuario.populate(
      usuariosGrupo,
      {
        path: "usuarioContacto",
        select: ["nombre", "avatar", "codigoContacto"],
      }
    );
    
    res.json({ listaUsuariosGrupo });
  } catch (error) {
    console.error('Error in groupMembers:', error);
    return res.status(500).json({
      ok: false,
      msg: 'Error al obtener miembros del grupo'
    });
  }
};

const groupsByMember = async (req, res = response) => {
  try {
    var usuario = await Usuario.findOne({ _id: { $eq: req.body.codigo } });
    if (!usuario) {
      return res.status(404).json({
        ok: false,
        msg: 'Usuario no encontrado'
      });
    }

    var grupos = await GrupoUsuario.find({ usuarioContacto: { $eq: usuario } });
    const gruposPopulated = await Grupo.populate(grupos, { path: "grupo" });
    const gruposFinal = await Usuario.populate(
      gruposPopulated,
      {
        path: "grupo.usuarioCrea",
        select: ["nombre", "avatar", "codigoContacto"],
      }
    );

    let gruposObject = JSON.parse(JSON.stringify(gruposFinal));
    let mappedGroupData = await Promise.all(
      gruposObject.map(async (row) => {
                // Find the total members count for each group
                row.totalMembers = await GrupoUsuario.find({
                  grupo: row?.grupo?._id,
                }).countDocuments();

                return row;
              })
            );
    res.json({ grupos: mappedGroupData });
  } catch (error) {
    console.error('Error in groupsByMember:', error);
    return res.status(500).json({
      ok: false,
      msg: 'Error al obtener grupos del usuario'
    });
  }
};

const groupByCode = async (req, res = response) => {
  var codigoGrupo = req.body.codigo;
  var grupo = await Grupo.findOne({ codigo: codigoGrupo }).then((group) => {
    res.json({ group });
  });
  // if(!grupo){
  //     res.json({ "error": "ERR104" });// GRUPO NO ENCONTRADO

  // }
};

const addGroup = async (req, res = response) => {
  var grupo = Grupo();
  var usuario = await Usuario.findOne({ _id: { $eq: req.body.uid } });
  var codigosUsuario = req.body.codigoUsuario;

  grupo.privateKey = req.body.privateKey;
  grupo.publicKey = req.body.publicKey;

  grupo.nombre = req.body.nombre;
  grupo.avatar = "tollray.png";
  grupo.descripcion = req.body.descripcion;
  grupo.usuarioCrea = usuario;
  grupo.fecha = req.body.fecha;

  var existeCodigo = true;
  while (existeCodigo) {
    codigo = codigoGrupo(20);
    grupo.codigo = codigo;
    if (codigo == null || existeCodigo)
      existeCodigo = await Grupo.findOne({ codigo });
  }
  grupo.save().then((group) => {
    addMembersToGroup(group, codigosUsuario);
    
    // Index group for search (async, don't block)
    try {
      const indexer = require('../services/search/indexer');
      indexer.indexGroup(group).catch(err => console.error('Search indexing error:', err));
    } catch (error) {
      console.error('Error indexing group:', error);
    }
    
    // Trigger feed generation (async, don't block)
    try {
      const feedGenerator = require('../services/feed/generator');
      feedGenerator.triggerFeedGeneration('group', {
        grupoId: group._id.toString()
      }).catch(err => console.error('Feed generation error:', err));
    } catch (error) {
      console.error('Error triggering feed generation:', error);
    }
  });
  res.json({
    ok: true,
    grupo,
  });
};

const updateGroup = async (req, res = response) => {
  var grupo = await Grupo.findOne({ codigo: { $eq: req.body.codigo } }).then(
    (group) => {
      if (req.body.nombre != null && req.body.nombre != "")
        group.nombre = req.body.nombre;

      if (req.body.avatar != null && req.body.avatar != "")
        group.avatar = req.body.avatar;

      if (req.body.descripcion != null && req.body.descripcion != "")
        group.descripcion = req.body.descripcion;

      if (req.body.usuarioCrea != null && req.body.usuarioCrea != "") {
        Usuario.find({ _id: { $eq: req.body.usuarioCrea } }).then((usu) => {
          group.usuarioCrea = usu;
        });
      }
      var msj = { grupo: group };
      Usuario.populate(
        group,
        { path: "usuarioCrea", select: ["nombre", "avatar", "codigoContacto"] },
        function (err, group) {
          msj = { grupo: group };
        }
      );

      GrupoUsuario.find({ grupo: { $eq: group } }).then((group) => {
        Usuario.populate(
          group,
          { path: "usuarioContacto" },
          function (err, group) {
            group.forEach((objeto, index) => {
              var user = objeto.usuarioContacto;
              if (user.online) io.to(user._id).emit("update-group", msj);
              else {
                var solicitud = Solicitud();
                solicitud.tipo = "update-group";
                solicitud.de = group.usuarioCrea;
                solicitud.para = user.uid;
                solicitud.mensaje = msj.toString();
                solicitud.save();
              }
            });
          }
        );
      });

      group.save().then(() => {
        // Index group for search (async, don't block)
        try {
          const indexer = require('../services/search/indexer');
          indexer.indexGroup(group).catch(err => console.error('Search indexing error:', err));
        } catch (error) {
          console.error('Error indexing group:', error);
        }
        
        // Trigger feed generation (async, don't block)
        try {
          const feedGenerator = require('../services/feed/generator');
          feedGenerator.triggerFeedGeneration('group', {
            grupoId: group._id.toString()
          }).catch(err => console.error('Feed generation error:', err));
        } catch (error) {
          console.error('Error triggering feed generation:', error);
        }
      });
    }
  );

  res.json({
    ok: true,
    grupo,
  });
};

const addMember = async (req, res = response) => {
  var codigoGrupo = req.body.codigoGrupo;
  var codigosUsuario = req.body.codigoUsuario;
  await Grupo.findOne({ codigo: { $eq: codigoGrupo } }).then((grupo) => {
    codigosUsuario.forEach((usuarioID) => {
      addMembersToGroup(grupo, usuarioID);
    });
  });

  res.json({
    ok: true,
  });
};
const updatGroupDisappearTime = async (req, res = response) => {
  if (
    !req.body.disappearMessageSetAt ||
    !req.body.disappearMessageTime ||
    !req.body.codigo
  ) {
    res.status(400).json({ ok: false, message: "Missing properties" });
    return;
  }
  const grupo = await Grupo.findOne({
    codigo: req.body.codigo,
  });
  if (grupo) {
    grupo.disappearMessageSetAt = new Date(req.body.disappearMessageSetAt);
    grupo.disappearMessageTime = req.body.disappearMessageTime;
    grupo.disappearedCheck = true;
    grupo.save();
  } else {
    return res.json({
      ok: false,
      message: "No group found",
    });
  }

  res.json({
    ok: true,
  });
};

const removeMember = async (req, res = response) => {
  var result = true;
  var grupo = await Grupo.findOne({ codigo: { $eq: req.body.codigoGrupo } });
  var usuario = await Usuario.findOne({ _id: { $eq: req.body.codigoUsuario } });
  console.log("grupo -> removeMember");
  console.log(req.body);
  GrupoUsuario.findOne({
    $and: [
      {
        grupo: { $eq: grupo },
        usuarioContacto: { $eq: usuario },
      },
    ],
  }).then((gu) => {
    Grupo.populate(gu, { path: "grupo" }, function (err, gu) {});
    GrupoUsuario.find({ grupo: { $eq: grupo } }).then((group) => {
      Usuario.populate(
        group,
        { path: "usuarioContacto" },
        function (err, group) {
          group.forEach((objeto, index) => {
            var user = objeto.usuarioContacto;
            var msj = { grupousuario: gu };
            if (user.online) io.to(user._id).emit("usuario-borrado-grupo", msj);
            else {
              var solicitud = Solicitud();
              solicitud.tipo = "usuario-borrado-grupo";
              solicitud.de = usuario.uid;
              solicitud.para = user.uid;
              solicitud.mensaje = msj.toString();
              solicitud.save();
            }
            gu.remove(); //elimina el usuario
          });
        }
      );
    });
  });

  res.json({
    ok: result,
  });
};

const removeGroup = async (req, res = response) => {
  Grupo.findOne({ codigo: { $eq: req.body.codigo } }).then((group) => {
    var msj = { grupo: group };
    GrupoUsuario.find({ grupo: { $eq: group } }).then((group) => {
      Usuario.populate(
        group,
        { path: "usuarioContacto" },
        function (err, group) {
          group.forEach((gU, i) => {
            var user = gU.usuarioContacto;
            console.log(gU.usuarioContacto);
            if (user.online) io.to(user._id).emit("grupo-borrado", msj);
            else {
              var solicitud = Solicitud({
                tipo: "grupo-borrado",
                de: user._id,
                para: user._id,
              });
              solicitud.save();
            }
            try {
              gU.remove();
            } catch (e) {}
          });
        }
      );
    });
    try {
      group.remove();
    } catch (e) {}
  });
  res.json({
    ok: true,
  });
};

const addMembersToGroup = async (grupo, codigosUsuario) => {
  await Usuario.find({ _id: { $in: codigosUsuario } }).then((user) => {
    user.forEach((value, i) => {
      var grupoUsuario = new GrupoUsuario({
        grupo: grupo,
        usuarioContacto: value._id,
        activo: 1,
      });
      grupoUsuario.save();
    });
  });
};

function codigoGrupo(num) {
  var longitud = num;
  var caracteres =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
  var cadena = "";
  var max = caracteres.length - 1;
  for (var i = 0; i < longitud; i++) {
    cadena += caracteres[Math.floor(Math.random() * (max + 1))];
  }
  return cadena;
}

module.exports = {
  addGroup,
  addMember,
  removeGroup,
  removeMember,
  groupMembers,
  updateGroup,
  groupByCode,
  groupsByMember,
  updatGroupDisappearTime,
};
