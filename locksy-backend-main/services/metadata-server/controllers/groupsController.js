/*
 * Groups Controller for Metadata Server
 * Handles group metadata operations with cache-aside pattern
 */

const { response } = require('express');
const Grupo = require('../../../models/grupo');
const GrupoUsuario = require('../../../models/grupo_usuario');
const Usuario = require('../../../models/usuario');
const Solicitud = require('../../../models/solicitud');
const cacheService = require('../../cache/cacheService');

// Socket.IO - try to import, fallback gracefully if not available
let io = null;
try {
  const socketModule = require('../../../sockets/socket');
  io = socketModule.io || null;
} catch (error) {
  console.warn('Socket.IO not available in Metadata Server:', error.message);
}

/**
 * Generate group code
 */
function codigoGrupo(num) {
  const longitud = num;
  const caracteres = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  let cadena = '';
  const max = caracteres.length - 1;
  for (let i = 0; i < longitud; i++) {
    cadena += caracteres[Math.floor(Math.random() * (max + 1))];
  }
  return cadena;
}

/**
 * Add members to group
 */
const addMembersToGroup = async (grupo, codigosUsuario) => {
  const users = await Usuario.find({ _id: { $in: codigosUsuario } });
  for (const user of users) {
    const grupoUsuario = new GrupoUsuario({
      grupo: grupo,
      usuarioContacto: user._id,
      activo: 1
    });
    await grupoUsuario.save();
  }
};

/**
 * Get group members
 * Cache: 30 minutes
 */
const groupMembers = async (req, res = response) => {
  try {
    const codigoGrupo = req.body.codigo;
    const cacheKey = `group:${codigoGrupo}:members`;

    // Try cache first
    const cached = await cacheService.get(cacheKey);
    if (cached) {
      return res.json({
        ...cached,
        cached: true
      });
    }

    const grupo = await Grupo.findOne({ codigo: codigoGrupo });
    if (!grupo) {
      return res.status(404).json({
        ok: false,
        msg: 'Grupo no encontrado'
      });
    }

    const listaUsuariosGrupo = await GrupoUsuario.find({
      grupo: { $eq: grupo._id }
    }).populate('usuarioContacto', 'nombre avatar codigoContacto').lean();

    const result = {
      ok: true,
      listaUsuariosGrupo,
      cached: false
    };

    // Cache result (30 minutes)
    await cacheService.set(cacheKey, result, 1800);

    res.json(result);
  } catch (error) {
    console.error('Error getting group members:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al obtener miembros del grupo'
    });
  }
};

/**
 * Get groups by member
 * Cache: 15 minutes
 */
const groupsByMember = async (req, res = response) => {
  try {
    const codigo = req.body.codigo;
    const cacheKey = `user:${codigo}:groups`;

    // Try cache first
    const cached = await cacheService.get(cacheKey);
    if (cached) {
      return res.json({
        ...cached,
        cached: true
      });
    }

    const usuario = await Usuario.findOne({ _id: { $eq: codigo } });
    if (!usuario) {
      return res.status(404).json({
        ok: false,
        msg: 'Usuario no encontrado'
      });
    }

    const grupos = await GrupoUsuario.find({
      usuarioContacto: { $eq: usuario._id }
    })
      .populate('grupo')
      .populate('grupo.usuarioCrea', 'nombre avatar codigoContacto')
      .lean();

    // Add total members count
    const gruposObject = JSON.parse(JSON.stringify(grupos));
    const mappedGroupData = await Promise.all(
      gruposObject.map(async (row) => {
        row.totalMembers = await GrupoUsuario.countDocuments({
          grupo: row?.grupo?._id
        });
        return row;
      })
    );

    const result = {
      ok: true,
      grupos: mappedGroupData,
      cached: false
    };

    // Cache result (15 minutes)
    await cacheService.set(cacheKey, result, 900);

    res.json(result);
  } catch (error) {
    console.error('Error getting groups by member:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al obtener grupos'
    });
  }
};

/**
 * Get group by code
 * Cache: 30 minutes
 */
const groupByCode = async (req, res = response) => {
  try {
    const codigoGrupo = req.body.codigo;
    const cacheKey = `group:${codigoGrupo}`;

    // Try cache first
    const cached = await cacheService.get(cacheKey);
    if (cached) {
      return res.json({
        ...cached,
        cached: true
      });
    }

    const group = await Grupo.findOne({ codigo: codigoGrupo }).lean();

    if (!group) {
      return res.status(404).json({
        ok: false,
        msg: 'Grupo no encontrado'
      });
    }

    const result = {
      ok: true,
      group,
      cached: false
    };

    // Cache result (30 minutes)
    await cacheService.set(cacheKey, result, 1800);

    res.json(result);
  } catch (error) {
    console.error('Error getting group by code:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al obtener grupo'
    });
  }
};

/**
 * Create group
 * Invalidates group caches
 */
const addGroup = async (req, res = response) => {
  try {
    const usuario = await Usuario.findOne({ _id: { $eq: req.body.uid } });
    if (!usuario) {
      return res.status(404).json({
        ok: false,
        msg: 'Usuario no encontrado'
      });
    }

    const codigosUsuario = req.body.codigoUsuario;
    const grupo = new Grupo();

    grupo.privateKey = req.body.privateKey;
    grupo.publicKey = req.body.publicKey;
    grupo.nombre = req.body.nombre;
    grupo.avatar = 'tollray.png';
    grupo.descripcion = req.body.descripcion;
    grupo.usuarioCrea = usuario;
    grupo.fecha = req.body.fecha;

    // Generate unique code
    let existeCodigo = true;
    let codigo;
    while (existeCodigo) {
      codigo = codigoGrupo(20);
      const existing = await Grupo.findOne({ codigo });
      existeCodigo = !!existing;
    }
    grupo.codigo = codigo;

    await grupo.save();
    await addMembersToGroup(grupo, codigosUsuario);

    // Index group for search (async, don't block)
    try {
      const indexer = require('../../search/indexer');
      await indexer.indexGroup(grupo).catch(err => console.error('Search indexing error:', err));
    } catch (error) {
      console.error('Error indexing group:', error);
    }

    // Queue notifications to new members (async, don't block)
    try {
      const { queueNotification } = require('../../notification/producer');
      const users = await Usuario.find({ _id: { $in: codigosUsuario } });
      for (const user of users) {
        if (user.firebaseid) {
          await queueNotification({
            userId: user._id.toString(),
            title: 'Agregado a grupo',
            body: `Fuiste agregado al grupo ${grupo.nombre}`,
            data: {
              type: 'group_added',
              groupId: grupo._id.toString(),
              groupCode: grupo.codigo
            }
          }).catch(err => console.error('Notification error:', err));
        }
      }
    } catch (error) {
      console.error('Error queueing notifications:', error);
    }

    // Trigger feed generation (async, don't block)
    try {
      const feedGenerator = require('../../feed/generator');
      await feedGenerator.triggerFeedGeneration('group', {
        grupoId: grupo._id.toString()
      }).catch(err => console.error('Feed generation error:', err));
    } catch (error) {
      console.error('Error triggering feed generation:', error);
    }

    // Invalidate cache
    await Promise.all([
      cacheService.deletePattern(`group:${codigo}:*`),
      cacheService.deletePattern(`user:*:groups`)
    ]).catch(err => console.error('Cache invalidation error:', err));

    res.json({
      ok: true,
      grupo
    });
  } catch (error) {
    console.error('Error creating group:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al crear grupo'
    });
  }
};

/**
 * Update group
 * Invalidates group caches
 */
const updateGroup = async (req, res = response) => {
  try {
    const grupo = await Grupo.findOne({ codigo: { $eq: req.body.codigo } });
    if (!grupo) {
      return res.status(404).json({
        ok: false,
        msg: 'Grupo no encontrado'
      });
    }

    if (req.body.nombre != null && req.body.nombre != '') {
      grupo.nombre = req.body.nombre;
    }
    if (req.body.avatar != null && req.body.avatar != '') {
      grupo.avatar = req.body.avatar;
    }
    if (req.body.descripcion != null && req.body.descripcion != '') {
      grupo.descripcion = req.body.descripcion;
    }
    if (req.body.usuarioCrea != null && req.body.usuarioCrea != '') {
      const usu = await Usuario.find({ _id: { $eq: req.body.usuarioCrea } });
      if (usu && usu.length > 0) {
        grupo.usuarioCrea = usu[0];
      }
    }

    await grupo.save();

    // Index group for search (async, don't block)
    try {
      const indexer = require('../../search/indexer');
      await indexer.indexGroup(grupo).catch(err => console.error('Search indexing error:', err));
    } catch (error) {
      console.error('Error indexing group:', error);
    }

    // Populate for response
    await grupo.populate('usuarioCrea', 'nombre avatar codigoContacto');
    const msj = { grupo: grupo.toJSON() };

    // Notify group members
    const grupoUsuarios = await GrupoUsuario.find({ grupo: { $eq: grupo._id } })
      .populate('usuarioContacto');

    for (const gU of grupoUsuarios) {
      const user = gU.usuarioContacto;
      if (io && user.online) {
        io.to(user._id).emit('update-group', msj);
      } else {
        // If socket.io not available or user offline, create solicitud
        const solicitud = new Solicitud({
          tipo: 'update-group',
          de: grupo.usuarioCrea._id.toString(),
          para: user._id.toString(),
          mensaje: JSON.stringify(msj)
        });
        await solicitud.save();
      }

      // Queue notification (async, don't block)
      try {
        const { queueNotification } = require('../../notification/producer');
        if (user.firebaseid) {
          await queueNotification({
            userId: user._id.toString(),
            title: 'Grupo actualizado',
            body: `El grupo ${grupo.nombre} fue actualizado`,
            data: {
              type: 'group_updated',
              groupId: grupo._id.toString(),
              groupCode: grupo.codigo
            }
          }).catch(err => console.error('Notification error:', err));
        }
      } catch (error) {
        console.error('Error queueing notification:', error);
      }
    }

    // Trigger feed generation (async, don't block)
    try {
      const feedGenerator = require('../../feed/generator');
      await feedGenerator.triggerFeedGeneration('group', {
        grupoId: grupo._id.toString()
      }).catch(err => console.error('Feed generation error:', err));
    } catch (error) {
      console.error('Error triggering feed generation:', error);
    }

    // Invalidate cache
    await Promise.all([
      cacheService.invalidateGroup(grupo._id.toString()),
      cacheService.deletePattern(`group:${grupo.codigo}:*`),
      cacheService.deletePattern('user:*:groups')
    ]).catch(err => console.error('Cache invalidation error:', err));

    res.json({
      ok: true,
      grupo: msj.grupo
    });
  } catch (error) {
    console.error('Error updating group:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al actualizar grupo'
    });
  }
};

/**
 * Add member to group
 * Invalidates group caches
 */
const addMember = async (req, res = response) => {
  try {
    const codigoGrupo = req.body.codigoGrupo;
    const codigosUsuario = req.body.codigoUsuario;

    const grupo = await Grupo.findOne({ codigo: { $eq: codigoGrupo } });
    if (!grupo) {
      return res.status(404).json({
        ok: false,
        msg: 'Grupo no encontrado'
      });
    }

    if (Array.isArray(codigosUsuario)) {
      for (const usuarioID of codigosUsuario) {
        await addMembersToGroup(grupo, [usuarioID]);
      }
    } else {
      await addMembersToGroup(grupo, [codigosUsuario]);
    }

    // Queue notifications to new members (async, don't block)
    try {
      const { queueNotification } = require('../../notification/producer');
      const userIds = Array.isArray(codigosUsuario) ? codigosUsuario : [codigosUsuario];
      const users = await Usuario.find({ _id: { $in: userIds } });
      for (const user of users) {
        if (user.firebaseid) {
          await queueNotification({
            userId: user._id.toString(),
            title: 'Agregado a grupo',
            body: `Fuiste agregado al grupo ${grupo.nombre}`,
            data: {
              type: 'group_member_added',
              groupId: grupo._id.toString(),
              groupCode: grupo.codigo
            }
          }).catch(err => console.error('Notification error:', err));
        }
      }
    } catch (error) {
      console.error('Error queueing notifications:', error);
    }

    // Trigger feed generation (async, don't block)
    try {
      const feedGenerator = require('../../feed/generator');
      await feedGenerator.triggerFeedGeneration('group', {
        grupoId: grupo._id.toString()
      }).catch(err => console.error('Feed generation error:', err));
    } catch (error) {
      console.error('Error triggering feed generation:', error);
    }

    // Invalidate cache
    await Promise.all([
      cacheService.deletePattern(`group:${codigoGrupo}:*`),
      cacheService.deletePattern('user:*:groups')
    ]).catch(err => console.error('Cache invalidation error:', err));

    res.json({
      ok: true
    });
  } catch (error) {
    console.error('Error adding member to group:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al agregar miembro al grupo'
    });
  }
};

/**
 * Remove member from group
 * Invalidates group caches
 */
const removeMember = async (req, res = response) => {
  try {
    const codigoGrupo = req.body.codigoGrupo;
    const codigoUsuario = req.body.codigoUsuario;

    const grupo = await Grupo.findOne({ codigo: { $eq: codigoGrupo } });
    const usuario = await Usuario.findOne({ _id: { $eq: codigoUsuario } });

    if (!grupo || !usuario) {
      return res.status(404).json({
        ok: false,
        msg: 'Grupo o usuario no encontrado'
      });
    }

    const gu = await GrupoUsuario.findOne({
      $and: [
        { grupo: { $eq: grupo._id } },
        { usuarioContacto: { $eq: usuario._id } }
      ]
    }).populate('grupo');

    if (!gu) {
      return res.status(404).json({
        ok: false,
        msg: 'Miembro no encontrado en el grupo'
      });
    }

    // Notify other members
    const group = await GrupoUsuario.find({ grupo: { $eq: grupo._id } })
      .populate('usuarioContacto');

    const msj = { grupousuario: gu.toJSON() };

    for (const gU of group) {
      const user = gU.usuarioContacto;
      if (io && user.online) {
        io.to(user._id).emit('usuario-borrado-grupo', msj);
      } else {
        const solicitud = new Solicitud({
          tipo: 'usuario-borrado-grupo',
          de: usuario._id.toString(),
          para: user._id.toString(),
          mensaje: JSON.stringify(msj)
        });
        await solicitud.save();
      }
    }

    await gu.remove();

    // Invalidate cache
    await Promise.all([
      cacheService.deletePattern(`group:${codigoGrupo}:*`),
      cacheService.deletePattern('user:*:groups')
    ]).catch(err => console.error('Cache invalidation error:', err));

    res.json({
      ok: true
    });
  } catch (error) {
    console.error('Error removing member from group:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al eliminar miembro del grupo'
    });
  }
};

/**
 * Remove group
 * Invalidates group caches
 */
const removeGroup = async (req, res = response) => {
  try {
    const grupo = await Grupo.findOne({ codigo: { $eq: req.body.codigo } });
    if (!grupo) {
      return res.status(404).json({
        ok: false,
        msg: 'Grupo no encontrado'
      });
    }

    const msj = { grupo: grupo.toJSON() };
    const grupoUsuarios = await GrupoUsuario.find({ grupo: { $eq: grupo._id } })
      .populate('usuarioContacto');

    for (const gU of grupoUsuarios) {
      const user = gU.usuarioContacto;
      if (io && user.online) {
        io.to(user._id).emit('grupo-borrado', msj);
      } else {
        const solicitud = new Solicitud({
          tipo: 'grupo-borrado',
          de: user._id.toString(),
          para: user._id.toString()
        });
        await solicitud.save();
      }
      try {
        await gU.remove();
      } catch (e) {
        console.error('Error removing grupo usuario:', e);
      }
    }

    try {
      await grupo.remove();
    } catch (e) {
      console.error('Error removing grupo:', e);
    }

    // Invalidate cache
    await Promise.all([
      cacheService.deletePattern(`group:${grupo.codigo}:*`),
      cacheService.deletePattern('user:*:groups')
    ]).catch(err => console.error('Cache invalidation error:', err));

    res.json({
      ok: true
    });
  } catch (error) {
    console.error('Error removing group:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al eliminar grupo'
    });
  }
};

/**
 * Update group disappear time
 */
const updatGroupDisappearTime = async (req, res = response) => {
  try {
    if (
      !req.body.disappearMessageSetAt ||
      !req.body.disappearMessageTime ||
      !req.body.codigo
    ) {
      return res.status(400).json({
        ok: false,
        message: 'Missing properties'
      });
    }

    const grupo = await Grupo.findOne({
      codigo: req.body.codigo
    });

    if (!grupo) {
      return res.status(404).json({
        ok: false,
        message: 'No group found'
      });
    }

    grupo.disappearMessageSetAt = new Date(req.body.disappearMessageSetAt);
    grupo.disappearMessageTime = req.body.disappearMessageTime;
    grupo.disappearedCheck = true;
    await grupo.save();

    // Invalidate cache
    await cacheService.invalidateGroup(grupo._id.toString());

    res.json({
      ok: true
    });
  } catch (error) {
    console.error('Error updating group disappear time:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al actualizar tiempo de desaparición'
    });
  }
};

module.exports = {
  addGroup,
  addMember,
  removeGroup,
  removeMember,
  groupMembers,
  updateGroup,
  groupByCode,
  groupsByMember,
  updatGroupDisappearTime
};

