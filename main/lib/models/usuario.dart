import 'dart:convert';

import 'package:CryptoChat/services/crypto.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

Usuario usuarioFromJson(String str) => Usuario.fromJson(json.decode(str));
String usuarioToJson(Usuario data) => json.encode(data.toJson());

class Usuario {
  Usuario({
    this.online,
    this.nuevo,
    this.nombre,
    this.email,
    this.lastSeen,
    this.uid,
    this.codigoContacto,
    this.avatar,
    this.verificado,
    this.idioma,
    this.referido,
    this.privateKey,
    required this.publicKey,
  });

  bool? online;
  String? nuevo;
  String? nombre;
  String? email;
  String? lastSeen;
  String? uid;
  String? codigoContacto;
  String? avatar;
  bool? verificado;
  String? idioma;
  String? referido;
  String? publicKey;
  String? privateKey;

  void printUsuario() {
    debugPrint('Usuario {');
    debugPrint('  online: $online');
    debugPrint('  nuevo: $nuevo');
    debugPrint('  nombre: $nombre');
    debugPrint('  email: $email');
    debugPrint('  lastSeen: $lastSeen');
    debugPrint('  uid: $uid');
    debugPrint('  codigoContacto: $codigoContacto');
    debugPrint('  avatar: $avatar');
    debugPrint('  verificado: $verificado');
    debugPrint('  idioma: $idioma');
    debugPrint('  referido: $referido');
    debugPrint('  publicKey: $publicKey');
    debugPrint('  privateKey: $privateKey');
    debugPrint('}');
  }

  factory Usuario.fromJson(Map<String, dynamic> json) {
    // Handle privateKey - backend now sends it already decrypted (password-encrypted storage)
    // For new accounts: backend decrypts encryptedPrivateKey using password and sends plain privateKey
    // For old accounts: privateKey may not be in response (legacy accounts without encryptedPrivateKey)
    String? privateKeyString;
    if (json["privateKey"] != null && json["privateKey"] is String) {
      String privateKey = json["privateKey"] as String;
      // Backend sends privateKey already decrypted, so use it directly
      // Check if it looks like it might be encrypted (old format) vs plain (new format)
      // New format: privateKey is already decrypted RSA key (starts with -----BEGIN PRIVATE KEY----- or is ASN.1)
      // Old format: was encrypted with hardcoded key (would be base64 encrypted string)
      // CRITICAL FIX: Always try to decrypt first, since backend sends encrypted privateKey
      // Only skip decryption if it's clearly a PEM format (contains BEGIN/END markers)
      if (privateKey.contains('-----BEGIN') &&
          privateKey.contains('-----END')) {
        // This is already in PEM format (decrypted)
        print('[Usuario] ✅ Private key is in PEM format, using as-is');
        privateKeyString = privateKey;
      } else {
        // Try to decrypt - the backend sends AES-encrypted private keys
        try {
          print('[Usuario] 🔐 Attempting to decrypt private key...');
          privateKeyString =
              LocalCrypto().decrypt('Cryp16Zbqc@#4D%8', privateKey);
          print(
              '[Usuario] ✅ Private key decrypted successfully (length: ${privateKeyString.length})');
        } catch (e) {
          print('[Usuario] ⚠️ Decryption failed, will try using key as-is: $e');
          // If decryption fails, use the raw key (might be ASN.1 base64)
          privateKeyString = privateKey;
        }
      }
    }
    // If privateKey is not in response, it will be null (we'll use the one from secure storage)

    // Handle lastSeen - it might be null
    String? formattedDate;
    if (json['lastSeen'] != null && json['lastSeen'] is String) {
      try {
        DateTime utcDateTime = DateTime.parse(json['lastSeen']);
        // Step 2: Convert to local time
        DateTime localDateTime = utcDateTime.toLocal();
        // Step 3: Format the date as per your requirements
        formattedDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(localDateTime);
      } catch (e) {
        print('Error parsing lastSeen: $e');
        formattedDate = null;
      }
    }

    return Usuario(
        online: json["online"],
        nombre: json["nombre"],
        nuevo: json["nuevo"],
        email: json["email"],
        publicKey: json["publicKey"] ?? "",
        privateKey: privateKeyString, // Can be null if not in response
        uid: json["uid"] ?? json["_id"],
        codigoContacto: json['codigoContacto'],
        avatar: json['avatar'],
        lastSeen: formattedDate,
        verificado: json['verificado'] ?? false,
        idioma: json['idioma'] ?? "en",
        referido: json['referido'] ?? "");
  }

  Map<String, dynamic> toJson() => {
        "online": online,
        "nombre": nombre,
        "nuevo": nuevo,
        "email": email,
        "uid": uid,
        "codigoContacto": codigoContacto,
        "avatar": avatar,
        "lastSeen": lastSeen,
        "verificado": verificado,
        "idioma": idioma,
        "referido": referido,
        "publicKey": publicKey,
        "privateKey": privateKey,
      };
}
