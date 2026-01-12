const { Schema, model } = require('mongoose');
var Usuario = model('Usuario');
var Grupo = model('Grupo');


const MensajeSchema = Schema({
    grupo: {
        type: Schema.ObjectId,
        ref: "Grupo",
        default: null
    },
    de: {
        type: String,
        required: true
    },
    para: {
        type: String,
        required: true
    },
    // UPDATED: Message structure for E2E encryption
    // mensaje.ciphertext contains the encrypted message (base64 encoded)
    // Server cannot decrypt - only stores and forwards
    // Note: Validation is done at controller level using isValidCiphertext()
    mensaje: {
        type: Object,
        required: true,
        // Structure: {
        //   ciphertext: String (base64, required, min 100 chars),
        //   type: String (enum: 'text', 'image', 'video', 'audio', 'file', 'location'),
        //   fileUrl: String (optional),
        //   fileSize: Number (optional),
        //   fileName: String (optional),
        //   mimeType: String (optional),
        //   replyTo: ObjectId (optional),
        //   forwarded: Boolean (optional)
        // }
    },
    send: {
        type: Boolean,
        default: false
    },
    // originalMessage: {
    //     type: MensajeSchema,
    //     default: false
    // },
    incognito: {
        type: Boolean,
        default: false
    },
    usuario: {
        type: Schema.ObjectId,
        ref: "Usuario"
    },
    forwarded: {
        type: Boolean,
        default: false
    },
    reply: {
        type: Boolean,
        default: false
    },
    parentType: {
        type: String,
        default: null
    },
    parentSender: {
        type: String,
        default: null
    },
    parentContent: {
        type: String,
        default: null
    },
    // DISAPPEARING MESSAGES: When this date is reached, MongoDB will auto-delete the message
    expireAt: {
        type: Date,
        default: null
    },

}, {
    timestamps: true
});

// Add indexes for performance
MensajeSchema.index({ de: 1, para: 1, createdAt: -1 });
MensajeSchema.index({ para: 1, createdAt: -1 });
MensajeSchema.index({ grupo: 1, createdAt: -1 });
// DISAPPEARING MESSAGES: TTL index - MongoDB will auto-delete documents when expireAt is reached
MensajeSchema.index({ expireAt: 1 }, { expireAfterSeconds: 0 });

MensajeSchema.method('toJSON', function () {
    const { __v, _id, ...object } = this.toObject();
    object.mid = _id;
    // Ensure no plaintext is exposed
    return object;
})

module.exports = model('Mensaje', MensajeSchema);