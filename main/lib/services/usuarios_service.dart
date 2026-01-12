import 'package:CryptoChat/services/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:CryptoChat/helpers/funciones.dart';
import 'package:CryptoChat/models/contacto.dart';
import 'package:CryptoChat/models/grupo.dart';
import 'package:CryptoChat/models/grupo_usuario.dart';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:CryptoChat/models/usuario.dart';
import 'package:CryptoChat/models/usuarios_response.dart';
import 'package:CryptoChat/providers/db_provider.dart';
import 'package:CryptoChat/services/auth_service.dart';

import 'package:CryptoChat/global/environment.dart';

class UsuariosService {
  Future<List<Usuario>> getUsuarios() async {
    try {
      final resp = await http.get(Uri.parse('${Environment.apiUrl}/usuarios'),
          headers: {
            'Content-Type': 'application/json',
            'x-token': await AuthService.getToken()
          });

      final usuariosResponse = usuariosResponseFromJson(resp.body);
      return usuariosResponse.usuarios ?? [];
    } catch (e) {
      return [];
    }
  }

  Future<List<Contacto>> getSolicitudes(String codeUsuario) async {
    try {
      final data = {
        'code': codeUsuario,
        'activo': '0',
      };
      String url = '${Environment.apiUrl}/contactos/getContactos';

      final resp = await http.post(
        Uri.parse(url),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          'x-token': await AuthService.getToken()
        },
        body: jsonEncode(data),
      );

      var json = jsonDecode(resp.body);
      List<dynamic> solicitudes = json["solicitudes"];

      List<Contacto> solicitud =
          List<Contacto>.from(solicitudes.map((e) => Contacto.fromJson(e)));

      return solicitud;
    } catch (e) {
      return [];
    }
  }

  Future aceptarSolicitud(String codigoUsuario, String codigoContacto) async {
    try {
      final data = {
        'codigoUsuario': codigoUsuario,
        'codigoContacto': codigoContacto,
      };
      String url = '${Environment.apiUrl}/contactos/activateContacto';

      final resp = await http.post(
        Uri.parse(url),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          'x-token': await AuthService.getToken()
        },
        body: jsonEncode(data),
      );

      var json = jsonDecode(resp.body);

      return json['ok'];
    } catch (e) {}
  }

  Future rechazarSolicitud(String codigoUsuario, String codigoContacto) async {
    try {
      final data = {
        'codigoUsuario': codigoUsuario,
        'codigoContacto': codigoContacto,
      };
      String url = '${Environment.apiUrl}/contactos/dropContacto';

      final resp = await http.post(
        Uri.parse(url),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          'x-token': await AuthService.getToken()
        },
        body: jsonEncode(data),
      );
      return resp;
    } catch (e) {}
  }

  Future passwordChangeRequest(String email) async {
    var prefs = await SharedPreferences.getInstance();
    var lang = prefs.getString('language_code');
    lang = lang ?? "en";

    try {
      final data = {
        'email': cifrarPMS(email),
        'idioma': lang,
      };
      String url = '${Environment.apiUrl}/usuarios/recoveryPasswordS1';
      //print(url);
      final resp = await http.post(
        Uri.parse(url),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          'x-token': await AuthService.getToken(),
        },
        body: jsonEncode(data),
      );
      return resp.body;
    } catch (e) {
      // return (e);
    }
  }

  Future infoUserChange(dataUser, String tipo, uid) async {
    var prefs = await SharedPreferences.getInstance();
    var lang = prefs.getString('language_code');
    lang = lang ?? "en";

    try {
      final data = {
        'idioma': lang,
        'uid': uid,
        'referido': tipo == 'referido' ? cifrarPMS(dataUser) : null,
        'nuevo': tipo == 'new' ? cifrarPMS(dataUser) : null,
        'nombre': tipo == 'name' ? cifrarPMS(dataUser) : null,
        'email': tipo == 'email' ? cifrarPMS(dataUser) : null,
        'avatar': tipo == 'avatar' ? cifrarPMS(dataUser) : null,
        'clave': tipo == 'password' ? cifrarPMS(dataUser[1]) : null,
        'oldClave': tipo == 'password' ? cifrarPMS(dataUser[0]) : null,
      };
      String url = '${Environment.apiUrl}/usuarios/updateUsuario';
      final resp = await http.post(
        Uri.parse(url),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          'x-token': await AuthService.getToken(),
        },
        body: jsonEncode(data),
      );
      var error = jsonDecode(resp.body)['error'];
      var ok = jsonDecode(resp.body)['ok'];

      if (!error) {
        return ok;
      } else {
        return error;
      }
    } catch (e) {
      // return (e);
    }
    return lang;
  }

  Future<dynamic> guardarPreguntas(preguntas, respuestas, uid) async {
    try {
      final data = {
        'uid': uid,
        'pregunta1': preguntas[0],
        'pregunta2': preguntas[1],
        'pregunta3': preguntas[2],
        'pregunta4': preguntas[3],
        'respuesta1': respuestas[0],
        'respuesta2': respuestas[1],
        'respuesta3': respuestas[2],
        'respuesta4': respuestas[3],
      };
      String url = '${Environment.apiUrl}/usuarios/registrarPreguntas';

      final resp = await http
          .post(
        Uri.parse(url),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          'x-token': await AuthService.getToken(),
        },
        body: jsonEncode(data),
      )
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Request timeout');
        },
      );

      if (resp.statusCode == 200) {
        var json = jsonDecode(resp.body);
        return json['ok']; // Returns 'MSG102' on success, or false on error
      } else {
        print('Error status: ${resp.statusCode}');
        print('Error body: ${resp.body}');
        return false;
      }
    } catch (e) {
      print('Error in guardarPreguntas: $e');
      rethrow; // Re-throw so catchError in the UI can handle it
    }
  }

  Future<void> getGrupoUsuario(codigo) async {
    final data = {
      'codigo': codigo,
    };
    String url = '${Environment.apiUrl}/grupos/groupMembers';
    final res = await http.post(
      Uri.parse(url),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        'x-token': await AuthService.getToken()
      },
      body: jsonEncode(data),
    );
    var json = jsonDecode(res.body);
    // //print(json['listaUsuariosGrupo'][0]['usuarioContacto']['nombre']);
    var miembros = json['listaUsuariosGrupo'];
    List datalist = miembros;

    List<GrupoUsuario> miembros0 = [];

    for (var item in datalist) {
      var e = item['usuarioContacto'];
      GrupoUsuario miembro = GrupoUsuario();
      miembro.codigoGrupo = codigo;
      miembro.uidUsuario = e['_id'];
      miembro.codigoUsuario = e['codigoContacto'];
      miembro.avatarUsuario = e['avatar'];
      miembro.nombreUsuario = e['nombre'];
      miembros0.add(miembro);
    }
    await DBProvider.db.nuevoMiembro(miembros0, codigo);
    // return value;
  }

  addMemberGroup(codigo, usuarios) async {
    final data = {
      'codigoGrupo': codigo,
      'codigoUsuario': usuarios,
    };
    String url = '${Environment.apiUrl}/grupos/addMember';
    await http.post(
      Uri.parse(url),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        'x-token': await AuthService.getToken()
      },
      body: jsonEncode(data),
    );
    // Response handled
    //print('addMemberGroup: ${jsonDecode((await http.post(...)).body)}');
  }

  removeMemberGroup(codigo, usuario) async {
    final data = {
      'codigoGrupo': codigo,
      'codigoUsuario': usuario,
    };
    String url = '${Environment.apiUrl}/grupos/removeMember';
    await http.post(
      Uri.parse(url),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        'x-token': await AuthService.getToken()
      },
      body: jsonEncode(data),
    );
    // Response handled
    //print('removeMemberGroup: ${jsonDecode((await http.post(...)).body)}');
  }

  deleteGroup(codigo) async {
    final data = {
      'codigo': codigo,
    };
    String url = '${Environment.apiUrl}/grupos/removeGroup';
    final res = await http.post(
      Uri.parse(url),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        'x-token': await AuthService.getToken()
      },
      body: jsonEncode(data),
    );
    var json = jsonDecode(res.body);
    return json['ok'];
  }

  updateGroup({codigo, nombre, avatar, descripcion, usuario}) async {
    final data = {
      'codigo': codigo,
      'nombre': nombre,
      'avatar': avatar,
      'descripcion': descripcion,
      'usuarioCrea': usuario,
    };
    String url = '${Environment.apiUrl}/grupos/updateGroup';
    final res = await http.post(
      Uri.parse(url),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        'x-token': await AuthService.getToken()
      },
      body: jsonEncode(data),
    );
    var json = jsonDecode(res.body);
    //print('updateGroup: $json');
    return json['ok'];
  }

  Future<List> getnameAvatarImg(value) async {
    String url = '${Environment.apiUrl}/archivos/$value';
    final res = await http.get(
      Uri.parse(url),
    );
    List json = jsonDecode(res.body);
    return json;
  }

  Future<List<Grupo>> getListGroup(codigo) async {
    final data = {'codigo': codigo};
    String url = '${Environment.apiUrl}/grupos/groupsByMember';
    final res = await http.post(
      Uri.parse(url),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        'x-token': await AuthService.getToken()
      },
      body: jsonEncode(data),
    );
    //print(res.body);
    try {
      var json = jsonDecode(res.body);
      var list = json['grupos'];
      List<Grupo> listGrupos = [];
      list.forEach((element) {
        var grupo = element['grupo'];
        var usuarioCrea = jsonEncode({
          'uid': grupo['usuarioCrea']['_id'],
          'nombre': grupo['usuarioCrea']['nombre'],
          'avatar': grupo['usuarioCrea']['avatar'],
          'codigoContacto': grupo['usuarioCrea']['codigoContacto'],
        });
        Grupo newGrupo = Grupo();
        newGrupo.codigo = grupo['codigo'];
        newGrupo.nombre = grupo['nombre'];
        newGrupo.descripcion = grupo['descripcion'];
        newGrupo.avatar = grupo['avatar'];
        newGrupo.fecha = grupo['fecha'];

        newGrupo.publicKey = grupo['publicKey'];

        String EncryptedPrivateKey = grupo['privateKey'];
        String decryptedprivateKeyString =
            LocalCrypto().decrypt('Cryp16Zbqc@#4D%8', EncryptedPrivateKey);

        newGrupo.privateKey = decryptedprivateKeyString;

        newGrupo.usuarioCrea = usuarioCrea.toString();
        DBProvider.db.nuevoGrupo(newGrupo);
        listGrupos.add(newGrupo);
      });
      //print('getListGroup');
      return listGrupos;
    } catch (e) {
      List<Grupo> x = [];
      return x;
    }
  }

  sendSolicitud(uid, tipo, desc) async {
    final data = {
      'uid': uid,
      'tipo': tipo,
      'desc': desc,
    };
    String url = '${Environment.apiUrl}/usuarios/report';
    await http.post(
      Uri.parse(url),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        'x-token': await AuthService.getToken()
      },
      body: jsonEncode(data),
    );
    // Response handled
    //print('sendReport: ${jsonDecode((await http.post(...)).body)}');
  }

  getMyMessage(uid) async {
    // This endpoint returns 404 - skip it to avoid errors
    debugPrint('[getMyMessage] Skipping - endpoint not implemented (404)');
    return;
    try {
      final data = {
        'uid': uid,
      };
      String url = '${Environment.apiUrl}/usuarios/get-offline-data';
      final resp = await http
          .post(
        Uri.parse(url),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          'x-token': await AuthService.getToken()
        },
        body: jsonEncode(data),
      )
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('[getMyMessage] Request timeout after 10 seconds');
          throw TimeoutException('Request timeout');
        },
      );

      // Check if endpoint exists (404 means endpoint doesn't exist)
      if (resp.statusCode == 404) {
        debugPrint(
            '[getMyMessage] Endpoint not found (404) - endpoint may not be implemented');
        return;
      }

      // Log success but don't process response (legacy endpoint)
      if (resp.statusCode == 200) {
        debugPrint('[getMyMessage] Successfully fetched offline data');
      }
    } catch (e) {
      // Silently handle errors - this is a legacy endpoint that may not exist
      debugPrint('[getMyMessage] Error: $e');
    }
  }

  Future validaPago(uid, payDetail, broker, valor) async {
    final data = {
      'id_usuario': uid,
      'data': payDetail,
      'broker': broker,
      'valor': valor,
    };
    String url = '${Environment.apiUrl}/admin/validaPagos';
    final res = await http.post(
      Uri.parse(url),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        'x-token': await AuthService.getToken()
      },
      body: jsonEncode(data),
    );
    return res.body;
  }
}
