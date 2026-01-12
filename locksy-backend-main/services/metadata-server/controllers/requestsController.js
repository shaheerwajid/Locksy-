/*
 * Requests Controller for Metadata Server
 * Handles request metadata operations
 */

const Solicitud = require('../../../models/solicitud');
const Incognito = require('../../../models/incognito');

/**
 * Search requests
 */
const buscarSolicitudes = async (req, res) => {
  try {
    const para = req.params.para;
    
    const solicitudes = await Solicitud.find({
      $and: {
        tipo: { $eq: 'eliminar-todos' },
        para: { $eq: para }
      }
    });

    // Remove found requests
    if (solicitudes && solicitudes.length > 0) {
      await Solicitud.deleteMany({
        _id: { $in: solicitudes.map(s => s._id) }
      });
    }

    res.json({
      ok: true,
      solicitudes
    });
  } catch (error) {
    console.error('Error searching solicitudes:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al buscar solicitudes'
    });
  }
};

/**
 * Save delete all request
 */
const guardarSolicitudEliminarTodos = async (sol) => {
  try {
    const solicitud = new Solicitud(sol);
    await solicitud.save();
    return solicitud;
  } catch (error) {
    console.error('Error saving solicitud:', error);
    throw error;
  }
};

/**
 * Search incognitos
 */
const buscarIncognitos = async (req, res) => {
  try {
    const para = req.params.para;
    
    const incognitos = await Incognito.find({
      para: { $eq: para }
    });

    // Remove found incognitos
    if (incognitos && incognitos.length > 0) {
      await Incognito.deleteMany({
        _id: { $in: incognitos.map(i => i._id) }
      });
    }

    res.json({
      ok: true,
      incognito: incognitos
    });
  } catch (error) {
    console.error('Error searching incognitos:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al buscar incognitos'
    });
  }
};

/**
 * Save incognito
 */
const guardarIncognito = async (incog) => {
  try {
    const incognito = new Incognito(incog);
    await incognito.save();
    return incognito;
  } catch (error) {
    console.error('Error saving incognito:', error);
    throw error;
  }
};

module.exports = {
  buscarSolicitudes,
  guardarSolicitudEliminarTodos,
  buscarIncognitos,
  guardarIncognito
};


