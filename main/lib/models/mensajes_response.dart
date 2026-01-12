import 'dart:convert';

MensajesResponse mensajesResponseFromJson(String str) =>
    MensajesResponse.fromJson(json.decode(str));

String mensajesResponseToJson(MensajesResponse data) =>
    json.encode(data.toJson());

class MensajesResponse {
  MensajesResponse({
    this.ok,
    this.mensajes,
  });

  bool? ok;
  List<Mensaje>? mensajes;

  factory MensajesResponse.fromJson(Map<String, dynamic> json) =>
      MensajesResponse(
        ok: json["ok"],
        mensajes: List<Mensaje>.from(
            json["mensajes"].map((x) => Mensaje.fromJson(x))),
      );

  Map<String, dynamic> toJson() => {
        "ok": ok,
        "mensajes": List<dynamic>.from(mensajes!.map((x) => x.toJson())),
      };
}

// class Mensaje {
//   Mensaje({
//     this.rowid,
//     this.de,
//     this.para,
//     this.mensaje,
//     this.createdAt,
//     this.updatedAt,
//     this.uid,
//     this.nombreEmisor,
//     this.incognito,
//     this.enviado,
//     this.recibido,
//     this.descargado,
//     this.forwarded = false,
//   });

//   int? rowid;
//   String? de;
//   String? para;
//   String? mensaje;
//   String? createdAt;
//   String? updatedAt;
//   String? uid;
//   String? nombreEmisor;
//   int? incognito;
//   int? enviado;
//   int? recibido;
//   int? descargado;
//   bool forwarded ;

//   factory Mensaje.fromJson(Map<String, dynamic> json) => Mensaje(
//         rowid: json["rowid"],
//         de: json["de"],
//         para: json["para"],
//         mensaje: json["mensaje"],
//         createdAt: json["createdAt"].toString(),
//         updatedAt: json["updatedAt"].toString(),
//         uid: json["uid"],
//         nombreEmisor: json["nombreEmisor"],
//         incognito: json["incognito"],
//         enviado: json["enviado"] ?? 0,
//         recibido: json["recibido"] ?? 0,
//         descargado: json["descargado"] ?? 1,
//       );

//   Map<String, dynamic> toJson() => {
//         "rowid": rowid,
//         "de": de,
//         "para": para,
//         "mensaje": mensaje,
//         "createdAt": createdAt.toString(),
//         "updatedAt": updatedAt.toString(),
//         "uid": uid,
//         "nombreEmisor": nombreEmisor,
//         "incognito": incognito,
//         "enviado": enviado ?? 0,
//         "recibido": recibido ?? 0,
//         "descargado": descargado ?? 1,
//       };
// }

class Mensaje {
  Mensaje(
      {this.rowid,
      this.de,
      this.para,
      this.mensaje,
      this.createdAt,
      this.updatedAt,
      this.uid,
      this.nombreEmisor,
      this.incognito,
      this.enviado,
      this.parentSender,
      this.recibido,
      this.descargado,
      this.forwarded = false,
      this.parentType = '',
      this.parentContent = '',
      this.isReply = false,
      this.isSelected = false,
      this.upload = 1.0,
      required this.deleted});

  int? rowid;
  String? de;
  String? para;
  String? mensaje;
  String? createdAt;
  String? updatedAt;
  String? uid;
  String? nombreEmisor;
  int? incognito;
  int? enviado;
  int? recibido;

  double? upload;
  int? descargado;
  bool forwarded;
  bool deleted;

  bool isReply;
  bool isSelected;
  String? parentType;
  String? parentContent;
  String? parentSender;

  // New field for replied message

  factory Mensaje.fromJson(Map<String, dynamic> json) => Mensaje(
      rowid: json["rowid"],
      de: json["de"],
      para: json["para"],
      mensaje: json["mensaje"],
      createdAt: json["createdAt"].toString(),
      updatedAt: json["updatedAt"].toString(),
      uid: json["uid"],
      nombreEmisor: json["nombreEmisor"],
      incognito: json["incognito"],
      enviado: json["enviado"] ?? 0,
      recibido: json["recibido"] ?? 0,
      descargado: json["descargado"] ?? 1,
      isReply: json["reply"],
      forwarded: json["forwarded"],
      parentType: json["parentType"],
      parentContent: json["parentContent"],
      deleted: json["deleted"],
      parentSender: json["parentSender"]);

  Map<String, dynamic> toJson() => {
        "rowid": rowid,
        "de": de,
        "para": para,
        "mensaje": mensaje,
        "createdAt": createdAt.toString(),
        "updatedAt": updatedAt.toString(),
        "uid": uid,
        "nombreEmisor": nombreEmisor,
        "incognito": incognito,
        "enviado": enviado ?? 0,
        "recibido": recibido ?? 0,
        "descargado": descargado ?? 1,
        "forwarded": forwarded ? 1 : 0, // Convert bool to int for SQLite
        "reply": isReply ? 1 : 0, // Convert bool to int for SQLite
        "parentType": parentType,
        "parentContent": parentContent,
        "parentSender": parentSender,
        "deleted": deleted ? 1 : 0,
        // Convert repliedMessage to JSON
      };
}
