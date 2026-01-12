const { Schema, model } = require("mongoose");

const ContactoSchema = Schema({
  fecha: {
    type: String,
    required: true,
  },
  activo: {
    type: String,
  },
  incognito: {
    type: String,
    default: "no",
  },
  usuario: {
    type: Schema.ObjectId,
    ref: "Usuario",
  },
  publicKey: {
    type: String,
  },
  contacto: {
    type: Schema.ObjectId,
    ref: "Usuario",
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
  isBlocked: {
    type: Boolean,
    default: false, // Default to `false`
  },
});

ContactoSchema.method("toJSON", function () {
  const { _id, ...object } = this.toObject();
  return object;
});

// ContactoSchema.post("find", async function (contactos) {
//   const Usuario = require("./usuario");
//   const contactosObj = JSON.parse(JSON.stringify(contactos));
//   for (const contacto of contactosObj) {
//     const usuario = await Usuario.findById(contacto.usuario)
//       .select("blockUsers")
//       .lean();
//     usuario.blockUsers = usuario?.blockUsers.map((id) => id.toString());
//     contacto.isBlocked =
//       usuario?.blockUsers.includes(contacto.contacto.toString()) || false;
//   }
// });

module.exports = model("Contacto", ContactoSchema);
