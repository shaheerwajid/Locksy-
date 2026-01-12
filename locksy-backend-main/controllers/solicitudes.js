const Solicitud = require('../models/solicitud');
const Incognito = require('../models/incognito');

const buscarSolicitudes = async (req, res) => {
    try {
        const solicitudes = await Solicitud.find({
            $and: [
                { tipo: { $eq: "eliminar-todos" } },
                { para: { $eq: req.params.para } }
            ]
        });
        
        // Remove found solicitudes
        if (solicitudes && solicitudes.length > 0) {
            await Solicitud.deleteMany({
                _id: { $in: solicitudes.map(s => s._id) }
            });
        }
        
        res.json({ solicitudes: solicitudes || [] });
    } catch (error) {
        console.error('Error buscando solicitudes:', error);
        res.status(500).json({
            ok: false,
            msg: 'Error al buscar solicitudes'
        });
    }
};

const guardarSolicitudEliminarTodos = async (sol) => {
    const solicitud = new Solicitud(sol);
    solicitud.save();
    return solicitud;
}

const buscarIncognitos = async (req, res) => {
    const incognitos = await Incognito
        .find({ para: { $eq: req.params.para } })
        .then((incognito) => {
            Solicitud.remove(incognito);
        });
    res.json({ incognito: incognitos });
};

const guardarIncognito = async (incog) => {
    const incognito = new Incognito(incog);
    incognito.save();
    return incognito;
}

module.exports = {
    buscarSolicitudes,
    guardarSolicitudEliminarTodos,
    buscarIncognitos,
    guardarIncognito
}