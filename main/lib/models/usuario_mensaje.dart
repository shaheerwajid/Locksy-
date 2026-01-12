class UsuarioMensaje {
  UsuarioMensaje({
    this.uid,
    this.nombre,
    this.avatar,
    this.online,
    this.email,
    this.codigoContacto,
    this.usuarioCrea,
    this.mensaje,
    this.fecha,
    this.lastSeen,
    this.publicKey,
    this.privateKey,
    this.esGrupo,
    this.deleted = false,
  });

  String? online;
  String? lastSeen;
  String? publicKey;
  String? privateKey;
  String? nombre;
  String? email;
  String? uid;
  String? codigoContacto;
  String? usuarioCrea;
  String? avatar;
  String? mensaje;
  String? fecha;
  int? esGrupo;
  bool deleted;

  Map<String, dynamic> toJson() => {
        "online": online,
        "nombre": nombre,
        "email": email,
        "uid": uid,
        "codigoContacto": codigoContacto,
        "usuarioCrea": usuarioCrea,
        "avatar": avatar,
        "mensaje": mensaje,
        "fecha": fecha,
        "esGrupo": esGrupo,
        "lastSeen": lastSeen,
        "deleted": deleted,
        "publicKey": publicKey,
        "privateKey": privateKey,
      };
}
