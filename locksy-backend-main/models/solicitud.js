const { Schema, model } = require("mongoose");
const SolicitudSchema = Schema(
  {
    tipo: {
      type: String,
      default: "eliminar-todos",
    },
    de: {
      type: String,
      required: true,
    },
    para: {
      type: String,
      required: true,
    },
    mensaje: {
      type: String,
      required: false,
    },
    publicKey: {
      type: String,
    },
  },
  {
    timestamps: true,
  }
);

SolicitudSchema.method("toJSON", function () {
  const { _id, ...object } = this.toObject();
  return object;
});

module.exports = model("Solicitud", SolicitudSchema);
