const { Schema, model } = require('mongoose');
var Usuario = model('Usuario');
var Grupo = model('Grupo');

const GrupoUsuarioSchema = Schema({
    grupo: {
        type: Schema.ObjectId,
        ref: "Grupo"
    },
    usuarioContacto: {
        type: Schema.ObjectId,
        ref: "Usuario"
    },
    activo: {
        type: Number,
        default: 0
    }
});

GrupoUsuarioSchema.method('toJSON', function () {
    const { _id, ...object } = this.toObject();
    return object;
})

module.exports = model('GrupoUsuario', GrupoUsuarioSchema);