const { Schema, model } = require('mongoose');
var Usuario = model('Usuario');

const PagoSchema = Schema({ 
    id_pago: {
        type: String
    },
    state: {
        type: String
    },
    cart: {
        type: String
    },
    value: {
        type: String
    },
    fecha_transaccion: {
        type: String
    },
    fecha_fin: {
        type: String
    },
    usuario: {
        type: Schema.ObjectId,
        ref: "Usuario"
    }
});

PagoSchema.method('toJSON', function () {
    const { _id, ...object } = this.toObject();
    return object;
})

module.exports = model('Pago', PagoSchema);