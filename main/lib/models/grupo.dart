import 'dart:convert';

Grupo grupoFromJson(String str) => Grupo.fromJson(json.decode(str));

String grupoToJson(Grupo data) => json.encode(data.toJson());

class Grupo {
  Grupo({
    this.codigo,
    this.nombre,
    this.avatar,
    this.descripcion,
    this.usuarioCrea,
    this.privateKey,
    this.publicKey,
    this.fecha,
  });

  String? nombre;
  String? descripcion;
  String? avatar;
  String? fecha;
  String? usuarioCrea;
  String? codigo;
  String? privateKey;
  String? publicKey;

  factory Grupo.fromJson(Map<String, dynamic> json) => Grupo(
        codigo: json['codigo'],
        nombre: json["nombre"],
        descripcion: json["descripcion"],
        avatar: json['avatar'],
        usuarioCrea: json['usuarioCrea'],
        fecha: json['fecha'],
        privateKey: json['privateKey'],
        publicKey: json['publicKey'],
      );

  Map<String, dynamic> toJson() => {
        "codigo": codigo,
        "nombre": nombre,
        "descripcion": descripcion,
        "avatar": avatar,
        "usuarioCrea": usuarioCrea,
        "fecha": fecha,
        "privateKey": privateKey,
        "publicKey": publicKey,
      };
}
