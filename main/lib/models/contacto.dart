// To parse this JSON data, do
//
//     final usuario = usuarioFromJson(jsonString);

import 'dart:convert';

import 'package:CryptoChat/models/usuario.dart';

Contacto usuarioFromJson(String str) => Contacto.fromJson(json.decode(str));

String usuarioToJson(Contacto data) => json.encode(data.toJson());

class Contacto {
  Contacto({
    this.usuario,
    this.contacto,
    this.fecha,
    this.activo,
    this.nuevo,
    this.incognito,
    this.publicKey,
  });

  Usuario? usuario;
  Usuario? contacto;
  String? fecha;
  String? publicKey;
  String? activo;
  String? nuevo;
  int? incognito;

  factory Contacto.fromJson(Map<String, dynamic> json) {
    // Validate required fields
    if (json["usuario"] == null || json["contacto"] == null) {
      throw const FormatException('Contacto.fromJson: usuario or contacto is null');
    }
    
    // Ensure usuario and contacto are maps
    if (json["usuario"] is! Map<String, dynamic>) {
      throw FormatException('Contacto.fromJson: usuario is not a Map, got ${json["usuario"].runtimeType}');
    }
    if (json["contacto"] is! Map<String, dynamic>) {
      throw FormatException('Contacto.fromJson: contacto is not a Map, got ${json["contacto"].runtimeType}');
    }
    
    return Contacto(
      usuario: Usuario.fromJson(json["usuario"] as Map<String, dynamic>),
      contacto: Usuario.fromJson(json["contacto"] as Map<String, dynamic>),
      fecha: json["fecha"],
      activo: json["activo"],
      nuevo: json["nuevo"],
      publicKey: json["publicKey"] ?? '',
      incognito: json["incognito"] == "no" ? 0 : 1,
    );
  }

  Map<String, dynamic> toJson() => {
        "usuario": usuario,
        "contacto": contacto,
        "fecha": fecha,
        "activo": activo,
        "nuevo": nuevo,
        'publicKey': publicKey,
        "incognito": incognito,
      };
}
