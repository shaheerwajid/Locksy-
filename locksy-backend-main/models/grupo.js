const { Schema, model } = require("mongoose");
var Usuario = model("Usuario");

const GrupoSchema = Schema({
  codigo: {
    type: String,
    required: true,
  },
  nombre: {
    type: String,
    required: true,
  },
  avatar: {
    type: String,
  },
  descripcion: {
    type: String,
  },
  usuarioCrea: {
    type: Schema.ObjectId,
    ref: "Usuario",
  },
  publicKey: {
    type: String,
  },
  privateKey: {
    type: String,
  },
  fecha: {
    type: String,
  },
  disappearMessageTime: {
    type: String,
    enum: ["0m", "1m", "5m", "15m", "12h", "24h", "48h", "7d", "14d", "21d"],
  },
  disappearMessageSetAt: {
    type: Date,
  },
  disappearedCheck: {
    type: Boolean,
    default: false,
  },
});

GrupoSchema.method("toJSON", function () {
  const { _id, ...object } = this.toObject();
  return object;
});

module.exports = model("Grupo", GrupoSchema);
