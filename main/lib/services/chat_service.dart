import 'dart:convert';

import 'package:CryptoChat/models/grupo.dart';
import 'package:CryptoChat/models/mensajes_response.dart';
import 'package:CryptoChat/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:CryptoChat/global/environment.dart';
import 'package:CryptoChat/models/usuario.dart';

class ChatService extends ChangeNotifier {
  String? toUid;
  String? groupUid;
  String? uid;

  Usuario? usuarioPara;
  Grupo? grupoPara;
  //ChatService({required this.uid, required this.toUid, required this.groupUid});
  List<Mensaje> messajes = [];

  /// Fetch chat history with pagination support.
  /// Returns decoded list; caller can inspect `hasMore` from response if needed.
  Future<List<Map<String, dynamic>>> getChat(
    String usuarioID, {
    int limit = 200,
    String? after,
  }) async {
    try {
      final query = <String, String>{'limit': '$limit'};
      if (after != null && after.isNotEmpty) {
        query['after'] = after;
      }

      final uri =
          Uri.parse('${Environment.apiUrl}/mensajes/$usuarioID').replace(
        queryParameters: query,
      );

      final resp = await http.get(uri, headers: {
        'Content-Type': 'application/json',
        'x-token': await AuthService.getToken()
      });

      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        if (decoded['ok'] == true && decoded['mensajes'] is List) {
          return List<Map<String, dynamic>>.from(
            (decoded['mensajes'] as List).map((item) =>
                Map<String, dynamic>.from(item as Map<String, dynamic>)),
          );
        }
      } else {
        debugPrint(
            '[ChatService] getChat failed with status ${resp.statusCode}');
      }
    } catch (e) {
      debugPrint('[ChatService] Error fetching chat history: $e');
    }
    return <Map<String, dynamic>>[];
  }

  Future<String> uploadFile(dynamic data) async {
    var response = await http.post(
        Uri.parse('${Environment.apiUrl}/archivos/upload-file'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'x-token': await AuthService.getToken()
        },
        body: jsonEncode(data));
    return response.body;
  }
}
