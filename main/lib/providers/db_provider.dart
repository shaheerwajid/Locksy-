import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:CryptoChat/models/grupo.dart';
import 'package:CryptoChat/models/grupo_usuario.dart';
import 'package:CryptoChat/models/mensajes_response.dart';
import 'package:CryptoChat/models/usuario.dart';
import 'package:CryptoChat/models/usuario_mensaje.dart';
import 'package:CryptoChat/models/objPago.dart';
import 'package:CryptoChat/widgets/chat_message.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';

import '../helpers/duration_helper.dart';

class DBProvider {
  static Database? _database;
  static final DBProvider db = DBProvider._();
  List<Mensaje> _mensaje = [];
  List<UsuarioMensaje> _usuarioMensaje = [];
  List<Usuario> _usuario = [];
  List<ObjPago> pagos = [];
  List<Grupo> _grupo = [];
  List<GrupoUsuario> _grupousuario = [];
  Mensaje? mensajeID;
  final _controller = StreamController<Mensaje>.broadcast();

  DBProvider._();

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    // _database = await deleteDatabasse();
    _database = await initDB();
    return _database!;
  }

  Stream<Mensaje> get stream => _controller.stream;

  Future<void> deleteOldRecords(Database db) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedDuration = prefs.getString('selectedDuration');

    Duration? duration = savedDuration != null
        ? DurationHelper.getDurationFromString(savedDuration)
        : null;
    if (duration != null) {
      final cutoffTime = DateTime.now().subtract(duration);
      final cutoffTimestamp = cutoffTime.toString();

      int result = await db.delete(
        'mensajes',
        where: 'createdAt < ?',
        whereArgs: [cutoffTimestamp],
      );

      debugPrint("Deleted $result old records older than $savedDuration.");
    }
  }

  deleteDatabasse() async {
    //print('Estoy Eliminando DB pms');
    // Get a location using getDatabasesPath
    var databasesPath = await getDatabasesPath();
    String path = join(databasesPath, 'pms.db');

    // Delete the database
    await deleteDatabase(path);
  }

  Future<void> deleteAllData() async {
    final db = await database;
    try {
      await db.delete('mensajes');
      await db.delete('contactos');
      await db.delete('pagos');
      await db.delete('grupos');
      await db.delete('grupousuario');
      print('[DBProvider] ✅ All local data deleted successfully');
    } catch (e) {
      print('[DBProvider] ❌ Error deleting all data: $e');
    }
  }

  initDB() async {
    //print('Estoy Iniciando DB pms');
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'pms.db');

    _database = await openDatabase(path,
        version: 3, // Increment version to trigger onUpgrade for deleted column
        onOpen: (db) async {
      // DISAPPEARING MESSAGES: Delete old records based on user's selected duration
      await deleteOldRecords(db);
    }, onUpgrade: (Database db, int oldVersion, int newVersion) async {
      // Add indexes for existing databases
      if (oldVersion < 2) {
        try {
          await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_mensajes_de_para ON mensajes(de, para)');
          await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_mensajes_createdAt ON mensajes(createdAt DESC)');
          await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_mensajes_enviado ON mensajes(enviado)');
          await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_mensajes_recibido ON mensajes(recibido)');
          await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_contactos_uid ON contactos(uid)');
          await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_grupos_codigo ON grupos(codigo)');
          await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_grupousuario_codigoGrupo ON grupousuario(codigoGrupo)');
          print('[DBProvider] Database indexes added successfully');
        } catch (e) {
          print('[DBProvider] Error adding indexes: $e');
          // Indexes might already exist, continue anyway
        }
      }

      // Add deleted column to contactos table for soft delete
      if (oldVersion < 3) {
        try {
          await db.execute(
              'ALTER TABLE contactos ADD COLUMN deleted INTEGER DEFAULT 0');
          await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_contactos_deleted ON contactos(deleted)');
          print('[DBProvider] Deleted column added to contactos table');
        } catch (e) {
          print('[DBProvider] Error adding deleted column: $e');
          // Column might already exist, continue anyway
        }
      }
    }, onCreate: (Database db, int version) async {
      //print('Estoy Creando DB pms');
      await db.execute(''
          'CREATE TABLE mensajes ('
          'de TEXT,'
          'para TEXT,'
          'mensaje TEXT, '
          'forwarded INTEGER DEFAULT 0, '
          'reply  INTEGER DEFAULT 0, '
          'parentType TEXT, '
          'parentSender TEXT, '
          'parentContent TEXT, '
          'createdAt DATETIME, '
          'updatedAt DATETIME, '
          'uid TEXT, '
          'nombreEmisor TEXT, '
          'incognito INTEGER DEFAULT 0, '
          'enviado INTEGER DEFAULT 0, '
          'recibido INTEGER DEFAULT 0, '
          'descargado INTEGER DEFAULT 1, '
          'deleted INTEGER DEFAULT 0, '
          'UNIQUE(de, para, mensaje, createdAt) '
          ')');
      await db.execute(''
          'CREATE TABLE contactos ('
          'nombre TEXT,'
          'apodo TEXT,'
          'email TEXT,'
          'lastSeen TEXT,'
          'codigoContacto TEXT,'
          'online TEXT,'
          'incognito INTEGER DEFAULT 0,'
          'nuevo TEXT,'
          'avatar TEXT,'
          'publicKey TEXT,'
          'especial INTEGER DEFAULT 0,'
          'deleted INTEGER DEFAULT 0,'
          'uid TEXT UNIQUE'
          ')'
          '');
      await db.execute(''
          'CREATE TABLE pagos ('
          'nombre TEXT,'
          'valor TEXT,'
          'fecha TEXT,'
          'fechaPago TEXT'
          ')'
          '');
      await db.execute(''
          'CREATE TABLE grupos ('
          'codigo TEXT UNIQUE,'
          'nombre TEXT,'
          'avatar TEXT,'
          'descripcion TEXT,'
          'usuarioCrea TEXT,'
          'especial INTEGER DEFAULT 0,'
          'publicKey TEXT,'
          'privateKey TEXT,'
          'fecha TEXT'
          ')'
          '');

      await db.execute(''
          'CREATE TABLE grupousuario ('
          'codigoGrupo TEXT,'
          'uidUsuario TEXT,'
          'codigoUsuario TEXT,'
          'avatarUsuario TEXT,'
          'nombreUsuario TEXT'
          ')'
          '');

      // Performance indexes for faster queries
      await db
          .execute('CREATE INDEX idx_mensajes_de_para ON mensajes(de, para)');
      await db.execute(
          'CREATE INDEX idx_mensajes_createdAt ON mensajes(createdAt DESC)');
      await db
          .execute('CREATE INDEX idx_mensajes_enviado ON mensajes(enviado)');
      await db
          .execute('CREATE INDEX idx_mensajes_recibido ON mensajes(recibido)');
      await db.execute('CREATE INDEX idx_contactos_uid ON contactos(uid)');
      await db.execute('CREATE INDEX idx_grupos_codigo ON grupos(codigo)');
      await db.execute(
          'CREATE INDEX idx_grupousuario_codigoGrupo ON grupousuario(codigoGrupo)');

      // Additional index for message deduplication using fecha (extracted from mensaje JSON)
      // This helps with faster duplicate detection
      await db.execute(
          'CREATE INDEX idx_mensajes_fecha_lookup ON mensajes(de, para, createdAt)');
    });
    return _database;
  }

  nuevoMensaje(Mensaje nuevoMensaje) async {
    final db = await database;

    try {
      Map<String, dynamic> msjInsertar = jsonDecode(nuevoMensaje.mensaje!);
      final fecha = msjInsertar["fecha"]?.toString() ?? '';
      final de = nuevoMensaje.de ?? '';
      final para = nuevoMensaje.para ?? '';

      // Improved duplicate check: Use fecha + de + para as unique identifier
      // This is more reliable than comparing entire JSON strings
      // Extract fecha from mensaje JSON for comparison
      final fechaInt =
          fecha.length >= 17 ? int.tryParse(fecha.substring(0, 17)) : null;

      if (fechaInt != null) {
        // Check for duplicate using fecha + de + para
        final existe = await db.rawQuery('''
          SELECT COUNT(*) as count FROM mensajes 
          WHERE de = ? AND para = ? 
          AND CAST(SUBSTR(mensaje, INSTR(mensaje, '"fecha":"') + 9, 17) AS INTEGER) = ?
          LIMIT 1
        ''', [de, para, fechaInt]);

        final count = existe.first['count'] as int? ?? 0;
        if (count > 0) {
          // Duplicate message found, skip insertion
          print(
              '[DBProvider] Duplicate message detected and skipped: fecha=$fechaInt, de=$de, para=$para');
          return null;
        }
      } else {
        // Fallback to original method if fecha parsing fails
        String content = msjInsertar["content"] ?? 'null';
        String msjBuscar =
            '${'{"type":"' + msjInsertar["type"]}","content":$content,"fecha":"$fecha","extension":"' +
                (msjInsertar["extension"] ?? '') +
                '"}';
        final existe = await db.query(
          'mensajes',
          where: 'mensaje=? AND de=? AND para=?',
          whereArgs: [msjBuscar, de, para],
          limit: 1,
        );

        if (existe.isNotEmpty) {
          print('[DBProvider] Duplicate message detected (fallback method)');
          return null;
        }
      }

      // No duplicate found, insert the message
      final res = await db.insert('mensajes', nuevoMensaje.toJson(),
          conflictAlgorithm: ConflictAlgorithm.ignore);

      if (res != 0) {
        fetchDataAndUpdateStream(nuevoMensaje);
      }
      return res;
    } catch (e) {
      print('[DBProvider] Error in nuevoMensaje: $e');
      // Fallback: try original insert with conflict ignore
      try {
        final res = await db.insert('mensajes', nuevoMensaje.toJson(),
            conflictAlgorithm: ConflictAlgorithm.ignore);
        if (res != 0) {
          fetchDataAndUpdateStream(nuevoMensaje);
        }
        return res;
      } catch (e2) {
        print('[DBProvider] Error in fallback insert: $e2');
        return null;
      }
    }
  }

  Future<List<Map<String, dynamic>>> getMensajeByFecha(
      String fecha, String usuarioActual) async {
    final db = await database;

    final dataList = await db.query(
      'mensajes',
      columns: ['mensaje'],
      where:
          '(para=? OR de=?) AND (CAST(SUBSTR(mensaje, INSTR(mensaje, \'"fecha":"\') + 9, 17) AS INTEGER) = ?)',
      whereArgs: [usuarioActual, usuarioActual, fecha],
      orderBy:
          "CAST(SUBSTR(mensaje, INSTR(mensaje, '\"fecha\":\"') + 9, 17) AS INTEGER) DESC",
    );

    return dataList;
  }

  messageSent(payload, column, estado) async {
    String dir = (await getApplicationDocumentsDirectory()).path;
    String fecha;
    var content;
    var type;
    var ext;
    var de;
    var para;
    var forwarded;
    var reply;
    var parentType;
    var parentContent;
    var parentSender;

    if (column == 'enviado') {
      fecha = payload['mensaje']["fecha"].split("Z")[0].toString();
      type = payload['mensaje']['type'];
      ext = payload['ext'];
      content = payload['mensaje']['content'];
      de = payload['de'];
      para = payload['para'];
      forwarded = payload['forwarded'];
      reply = payload['reply'];
      parentType = payload['parentType'];
      parentContent = payload['parentContent'];
      parentSender = payload['parentSender'];
    } else {
      fecha = jsonDecode(payload['mensaje'])["fecha"].split("Z")[0].toString();
      type = jsonDecode(payload['mensaje'])['type'];
      ext = jsonDecode(payload['mensaje'])['ext'];
      content = jsonDecode(payload['mensaje'])['content'];

      if (type != 'text' && type != 'images') {
        // For non-text, non-image files, construct local path
        ext = jsonDecode(payload['mensaje'])['extension'];
        content = '$dir/$fecha' + ext;
      }
      // For images, keep the URL as-is (network-first approach)
      // For text, keep content as-is
      de = payload['para'];
      para = payload['de'];
      forwarded = payload['forwarded'];
      reply = payload['reply'];
      parentType = payload['parentType'];
      parentContent = payload['parentContent'];
      parentSender = payload['parentSender'];
    }
    var mensaje = jsonEncode({
      'type': type,
      'content': content,
      'fecha': fecha,
      'extension': ext ?? ''
    });
    var state = (estado ? 1 : 0);
    final db = await database;
    /*
    var sql1 = 'SELECT * '
        'FROM  mensajes '
        'WHERE de = "$de" AND para = "$para" '
        'AND CAST(SUBSTR(mensaje, INSTR(mensaje, \'"fecha":"\') + 9, 17) AS INTEGER) = $fecha';
    final res1 = await db.rawUpdate(sql1);
    //print("❌--------- para : ${res1} ----  ");
    //print("=================================❌❌❌❌");
*/
    var sql = 'UPDATE mensajes '
        'SET $column = $state '
        'WHERE de = "$de" AND para = "$para" '
        'AND CAST(SUBSTR(mensaje, INSTR(mensaje, \'"fecha":"\') + 9, 17) AS INTEGER) = $fecha';

    final res = await db.rawUpdate(sql);
    //print("=============================================================");
    //print("=======================[actualizarEnviadoRecibido]=========");
    //print(res);

    //print("=========[End actualizarEnviadoRecibido]====================");
    //print("=============================================================");
    // db.query('mensajes').then((value) => //print(value.toString()));
    return res;
  }

  actualizarEnviadoRecibido(payload, column, estado) async {
    String dir = (await getApplicationDocumentsDirectory()).path;
    var fecha;
    var content;
    var type;
    var ext;
    var de;
    var para;
    var forwarded;
    var reply;
    var parentType;
    var parentContent;
    var parentSender;

    // Handle payload['mensaje'] - it might be a Map or a JSON string
    Map<String, dynamic> mensajeData;
    if (payload['mensaje'] is String) {
      mensajeData = jsonDecode(payload['mensaje']);
    } else if (payload['mensaje'] is Map) {
      mensajeData = Map<String, dynamic>.from(payload['mensaje']);
    } else {
      print(
          '[DBProvider] ERROR: mensaje is neither String nor Map: ${payload['mensaje']?.runtimeType}');
      return; // Exit early if mensaje is invalid
    }

    if (column == 'enviado') {
      // Extract fecha and remove any timezone suffix, keep only numeric part
      String rawFecha = mensajeData["fecha"]?.toString() ?? '';
      if (rawFecha.contains('Z')) {
        fecha = rawFecha.split("Z")[0];
      } else {
        fecha = rawFecha;
      }
      // Remove any non-numeric characters for consistent matching
      fecha = fecha.replaceAll(RegExp(r'[^\d]'), '');

      type = mensajeData['type'];
      ext = payload['ext'];
      content = mensajeData['content'];
      de = payload['de'];
      para = payload['para'];
      forwarded = payload['forwarded'];
      reply = payload['reply'];
      parentType = payload['parentType'];
      parentContent = payload['parentContent'];
      parentSender = payload['parentSender'];
    } else {
      // RECIBIDO - read receipt
      // Extract fecha and remove any timezone suffix
      String rawFecha = mensajeData["fecha"]?.toString() ?? '';
      if (rawFecha.contains('Z')) {
        fecha = rawFecha.split("Z")[0];
      } else {
        fecha = rawFecha;
      }
      // Remove any non-numeric characters for consistent matching
      fecha = fecha.replaceAll(RegExp(r'[^\d]'), '');

      type = mensajeData['type'];
      ext = mensajeData['ext'];
      content = mensajeData['content'];

      if (type != 'text' && type != 'images') {
        // For non-text, non-image files, construct local path
        ext = mensajeData['extension'];
        content = '$dir/' + fecha + ext;
      }
      // For images, keep the URL as-is (network-first approach)
      // For text, keep content as-is

      // CRITICAL: For read receipts, the payload has:
      // - de = person who READ the message (recipient)
      // - para = person who SENT the message (sender/us)
      // The original message in DB has de=sender, para=recipient
      // So we need to SWAP them back to match the original message
      de = payload['para']; // Original sender
      para = payload['de']; // Original recipient

      forwarded = payload['forwarded'];
      reply = payload['reply'];
      parentType = payload['parentType'];
      parentContent = payload['parentContent'];
      parentSender = payload['parentSender'];
    }

    // Use fecha timestamp for reliable matching
    // CRITICAL: Use integer extraction (same as other functions) for reliable matching
    // This extracts the numeric fecha from the JSON and compares as integer
    var state = (estado ? 1 : 0);
    final db = await database;

    // Ensure fecha is numeric only and at least 17 digits
    String fechaNumeric = fecha.replaceAll(RegExp(r'[^\d]'), '');
    if (fechaNumeric.length > 17) {
      fechaNumeric = fechaNumeric.substring(0, 17);
    }
    final fechaInt = int.tryParse(fechaNumeric) ?? 0;

    print('[DBProvider] ========== actualizarEnviadoRecibido ==========');
    print('[DBProvider] Column: $column, Estado: $estado');
    print('[DBProvider] de: $de, para: $para');
    print('[DBProvider] fecha (raw): $fecha');
    print('[DBProvider] fechaInt: $fechaInt');

    // Use integer comparison (same as messageSent and other queries)
    var sql = 'UPDATE mensajes '
        'SET $column = ? '
        'WHERE de = ? AND para = ? '
        'AND CAST(SUBSTR(mensaje, INSTR(mensaje, \'"fecha":"\') + 9, 17) AS INTEGER) = ?';

    final res = await db.rawUpdate(sql, [state, de, para, fechaInt]);

    print('[DBProvider] Rows updated: $res');
    if (res == 0) {
      print('[DBProvider] ⚠️ No rows updated! Checking if message exists...');
      // Debug: Check if message exists with these parameters
      final check = await db.query('mensajes',
          where: 'de = ? AND para = ?', whereArgs: [de, para], limit: 5);
      print(
          '[DBProvider] Messages found for de=$de, para=$para: ${check.length}');
      if (check.isNotEmpty) {
        // Check what fecha is stored in the messages
        for (var msg in check) {
          final storedMensaje = msg['mensaje']?.toString() ?? '';
          final match = RegExp(r'"fecha":"([^"]+)"').firstMatch(storedMensaje);
          if (match != null) {
            final storedFecha =
                match.group(1)?.replaceAll(RegExp(r'[^\d]'), '');
            print(
                '[DBProvider] Stored fecha: ${match.group(1)} (numeric: $storedFecha)');
          }
        }
      }
    } else {
      print('[DBProvider] ✅ Successfully updated $res row(s)');
    }
    print('[DBProvider] ================================================');

    return res;
  }

  updateContacto(String lastSeen, String uid) async {
    final db = await database;
    final res = await db.update(
      'contactos',
      {
        'lastSeen': lastSeen,
        'online': "0",
      },
      where: 'uid = ?',
      whereArgs: [uid],
    );
    final find = await db.query(
      'contactos',
      where: 'uid = ?',
      whereArgs: [uid],
    );
  }

  nuevoContacto(Usuario nuevoContacto) async {
    final db = await database;
    final find = await db
        .query('contactos', where: 'uid=?', whereArgs: [nuevoContacto.uid]);

    // Check if contact exists and is marked as deleted
    final isDeleted = find.isNotEmpty && (find.first['deleted'] == 1);

    // Skip updating contacts that are marked as deleted (prevent server sync from re-adding)
    if (isDeleted) {
      debugPrint(
          '[nuevoContacto] Skipping sync for deleted contact: ${nuevoContacto.uid}');
      return find;
    }

    if (find.isNotEmpty) {
      // Get existing deleted flag to preserve it
      final existingDeleted = find.first['deleted'] ?? 0;

      final res = await db.update(
        'contactos',
        {
          'nombre': nuevoContacto.nombre,
          'apodo': nuevoContacto.nombre,
          'email': nuevoContacto.email,
          'codigoContacto': nuevoContacto.codigoContacto,
          'online': nuevoContacto.online == true ? "1" : "0",
          'lastSeen': nuevoContacto.lastSeen,
          'nuevo': nuevoContacto.nuevo,
          'avatar': nuevoContacto.avatar,
          'publicKey': nuevoContacto.publicKey,
          'uid': nuevoContacto.uid,
          'deleted': existingDeleted, // Preserve deleted flag
        },
        where: 'uid = ?',
        whereArgs: [nuevoContacto.uid],
      );
    } else {
      final res = await db.insert(
          'contactos',
          {
            'nombre': nuevoContacto.nombre,
            'apodo': nuevoContacto.nombre,
            'email': nuevoContacto.email,
            'codigoContacto': nuevoContacto.codigoContacto,
            'online': nuevoContacto.online,
            'lastSeen': nuevoContacto.lastSeen,
            'nuevo': nuevoContacto.nuevo,
            'avatar': nuevoContacto.avatar,
            'publicKey': nuevoContacto.publicKey,
            'uid': nuevoContacto.uid,
            'deleted': 0, // New contacts are not deleted
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    return find;
  }

  nuevoGrupo(Grupo grupo) async {
    final db = await database;
    final find = await db.query(
      'grupos',
      where: 'codigo = ?',
      whereArgs: [grupo.codigo],
    );

    if (find.isNotEmpty) {
      final res = await db.update(
        'grupos',
        grupo.toJson(),
        where: 'codigo = ?',
        whereArgs: [grupo.codigo],
      );
    } else {
      final res = await db.insert('grupos', grupo.toJson(),
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    return find;
  }

  nuevoMiembro(List<GrupoUsuario> data, codGrupo) async {
    final db = await database;
    if (data.isNotEmpty) {
      data.forEach((e) async {
        final find = await db.query('grupousuario',
            where: 'codigoGrupo = ? AND uidUsuario = ?',
            whereArgs: [codGrupo, e.uidUsuario]);
        if (find.isNotEmpty) {
          final res = await db.update('grupousuario', e.toJson(),
              where: 'codigoGrupo = ? AND uidUsuario = ?',
              whereArgs: [codGrupo, e.uidUsuario]);
        } else {
          final res = await db.insert('grupousuario', e.toJson());
        }
      });
    }
  }

  borrarMensajesContacto(usuarioPara) async {
    final db = await database;
    final res = await db.delete(
      'mensajes',
      where: 'uid = ?',
      whereArgs: [usuarioPara],
    );
    return res;
  }

  /// Delete self-chat messages (where de == para)
  Future<int> deleteSelfChatMessages(String currentUserId) async {
    final db = await database;
    try {
      final result = await db.delete(
        'mensajes',
        where: 'de = ? AND para = ?',
        whereArgs: [currentUserId, currentUserId],
      );
      debugPrint('[DBProvider] Deleted $result self-chat messages');
      return result;
    } catch (e) {
      debugPrint('[DBProvider] Error deleting self-chat messages: $e');
      return 0;
    }
  }

  /// Clean up invalid chat data (self-chats, duplicates, empty threads)
  Future<Map<String, int>> cleanupInvalidChatData(String currentUserId) async {
    final results = <String, int>{};

    try {
      // Delete self-chat messages
      results['selfChatMessages'] = await deleteSelfChatMessages(currentUserId);

      // Delete contacts with own UID
      final db = await database;
      final deletedContacts = await db.delete(
        'contactos',
        where: 'uid = ?',
        whereArgs: [currentUserId],
      );
      results['selfContacts'] = deletedContacts;
      debugPrint('[DBProvider] Deleted $deletedContacts contacts with own UID');

      // Find and log duplicate messages (same de, para, fecha)
      final duplicateMessages = await db.rawQuery('''
        SELECT de, para, CAST(SUBSTR(mensaje, INSTR(mensaje, '"fecha":"') + 9, 17) AS INTEGER) as fecha, COUNT(*) as count
        FROM mensajes
        WHERE de != para
        GROUP BY de, para, fecha
        HAVING count > 1
      ''');
      results['duplicateMessageGroups'] = duplicateMessages.length;
      debugPrint(
          '[DBProvider] Found ${duplicateMessages.length} groups of duplicate messages');

      return results;
    } catch (e) {
      debugPrint('[DBProvider] Error in cleanupInvalidChatData: $e');
      return results;
    }
  }

  borrarMensajesDe(usuarioPara) async {
    final db = await database;
    final res = await db.delete(
      'mensajes',
      where: 'de = ?',
      whereArgs: [usuarioPara],
    );
    return res;
  }

  deleteMensajesByMenseje(List<ChatMessage> values) async {
    //print("✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅-----------deleteMensajesByMenseje ");

    final db = await database;

    String sql = "DELETE FROM mensajes WHERE ";
    List<dynamic> params = [];

    if (values.isNotEmpty) {
      for (var element in values) {
        sql += 'mensaje = ? OR '; // Use a placeholder for each mensaje

        // Construct the mensaje string safely
        String mensaje = '{"type":"${element.type!}",'
            '"content":"${element.texto != null ? element.texto!.replaceAll('\n', '\\n') : ''}",'
            '"fecha":"${element.fecha!}",'
            '"extension":"${element.exten != null ? element.exten! : ''}"}';

        // Add the mensaje string to the parameters list
        params.add(mensaje);
      }
      sql = sql.substring(0, sql.length - 4);

      final db = await database;
      final res = await db.rawUpdate(sql, params);
      //print("✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅-----------deleteMensajesByMenseje-{${res}} ");

      return res;
    }
  }

  deleteMSGWithMSGdeleted(List<ChatMessage> values) async {
    //print("✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅-----------deleteMensajesByMenseje ");

    String sql = 'UPDATE mensajes SET deleted = 1 WHERE ';
    List<dynamic> params = [];
    int res1 = 0;
    if (values.isNotEmpty) {
      for (var element in values) {
        if (element.deleted) {
          var rest = await deleteMensajesByMenseje([element]);
          res1 = rest;
          // return res;
        }
        sql += 'mensaje = ? OR '; // Use a placeholder for each mensaje

        // Construct the mensaje string safely
        String mensaje = '{"type":"${element.type!}",'
            '"content":"${element.texto != null ? element.texto!.replaceAll('\n', '\\n') : ''}",'
            '"fecha":"${element.fecha!}",'
            '"extension":"${element.exten != null ? element.exten! : ''}"}';

        // Add the mensaje string to the parameters list
        params.add(mensaje);
      }

      // Remove the last ' OR ' from the query
      sql = sql.substring(0, sql.length - 4);

      final db = await database;
      final res =
          await db.rawUpdate(sql, params); // Execute the query with the params

      //print("✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅-----------deleteMensajesByMensaje--{${res}}");

      return res + res1;
    }
  }

  //deleted

  deleteMensajeV2(values) async {
    final db = await database;
    String sql =
        'UPDATE mensajes SET deleted = 1 WHERE de = ? AND para = ? AND mensaje = ?';

    // Construct the mensaje JSON string
    String mensaje = '{"type":"${values['type']}",'
        '"content":"${values['texto'] != null ? values['texto']!.replaceAll('\n', '\\n') : ''}",'
        '"fecha":"${values['fecha']}",'
        '"extension":"${values['ext'] ?? ''}"}';

    // Execute the query using parameterized values
    final data =
        await db.rawUpdate(sql, [values['de'], values['para'], mensaje]);

    return data;
  }

  deleteMensaje(values) async {
    final db = await database;
    String sql = 'DELETE FROM mensajes WHERE de = \'' +
        values['de'] +
        '\' AND para = \'' +
        values['para'] +
        '\' AND  mensaje = \'{"type":"' +
        values['type'] +
        '","content":"' +
        values['texto'] +
        '","fecha":"' +
        values['fecha'] +
        '","extension":"' +
        (values['ext'] ?? '') +
        '"}\' ';
    final data = await db.rawDelete(sql);
    return data;
  }

  Future borrarALL() async {
    final db = await database;
    final res = await db.delete('mensajes');
    final respu = await db.delete('contactos');
    final respues = await db.delete('grupos');
    final respuesta = await db.delete('pagos');
    final respuestas = await db.delete('grupousuario');
  }

  Future<List<Mensaje>> getTodosMensajes2(
      usuarioActual, currentUserId, limit, offcet) async {
    final db = await database;

    // Check if usuarioActual is a group code (exists in grupos table)
    final grupoCheck = await db.query('grupos',
        where: 'codigo = ?', whereArgs: [usuarioActual], limit: 1);

    final bool isGroup = grupoCheck.isNotEmpty;

    if (isGroup) {
      // For group messages: filter by para = groupCode
      // Security note: Socket server only sends messages to group members
      final dataList = await db.rawQuery('''
  SELECT m.*
  FROM mensajes m
  WHERE m.para = ?
  ORDER BY CAST(SUBSTR(m.mensaje, INSTR(m.mensaje, '"fecha":"') + 9, 17) AS INTEGER) DESC
  LIMIT ? OFFSET ?
''', [usuarioActual, limit, offcet]);
      _mensaje = dataList.map((item) {
        return Mensaje(
          deleted: item['deleted'] == 1 ? true : false,
          de: item['de'].toString(),
          para: item['para'].toString(),
          mensaje: item['mensaje'].toString(),
          createdAt: item['createdAt'].toString(),
          updatedAt: item['updatedAt'].toString(),
          incognito: 0,
          enviado: int.parse(item['enviado'].toString()),
          recibido: int.parse(item['recibido'].toString()),
          nombreEmisor: item['nombreEmisor'].toString(),
          parentContent: item['parentContent'].toString(),
          parentSender: item['parentSender'].toString(),
          isReply: int.parse(item['reply'].toString()) == 1 ? true : false,
          forwarded:
              int.parse(item['forwarded'].toString()) == 1 ? true : false,
          parentType: item['parentType'].toString(),
        );
      }).toList();
      return _mensaje;
    } else {
      // For personal messages: filter by both users being involved
      final dataList = await db.query('mensajes',
          where: '((de=? AND para=?) OR (de=? AND para=?))',
          whereArgs: [
            currentUserId,
            usuarioActual,
            usuarioActual,
            currentUserId
          ],
          orderBy:
              "CAST(SUBSTR(mensaje, INSTR(mensaje, '\"fecha\":\"') + 9, 17) AS INTEGER) DESC",
          limit: limit,
          offset: offcet);
      _mensaje = dataList.map((item) {
        return Mensaje(
          deleted: item['deleted'] == 1 ? true : false,
          de: item['de'].toString(),
          para: item['para'].toString(),
          mensaje: item['mensaje'].toString(),
          createdAt: item['createdAt'].toString(),
          updatedAt: item['updatedAt'].toString(),
          incognito: 0,
          enviado: int.parse(item['enviado'].toString()),
          recibido: int.parse(item['recibido'].toString()),
          nombreEmisor: item['nombreEmisor'].toString(),
          parentContent: item['parentContent'].toString(),
          parentSender: item['parentSender'].toString(),
          isReply: int.parse(item['reply'].toString()) == 1 ? true : false,
          forwarded:
              int.parse(item['forwarded'].toString()) == 1 ? true : false,
          parentType: item['parentType'].toString(),
        );
      }).toList();
      return _mensaje;
    }
  }

  Future<List<Mensaje>> getTodosMensajes1(
      usuarioActual, currentUserId, limit) async {
    final db = await database;

    // Check if usuarioActual is a group code (exists in grupos table)
    final grupoCheck = await db.query('grupos',
        where: 'codigo = ?', whereArgs: [usuarioActual], limit: 1);

    final bool isGroup = grupoCheck.isNotEmpty;

    if (isGroup) {
      // For group messages: filter by para = groupCode
      // Security note: Socket server only sends messages to group members,
      // so if we have the message locally, we were authorized to receive it
      debugPrint(
          '[DBProvider] Loading group messages for groupCode: $usuarioActual');
      final dataList = await db.rawQuery('''
  SELECT m1.*, m2.mensaje AS parentMensaje
  FROM mensajes m1
  LEFT JOIN mensajes m2
  ON m1.parentContent = CAST(SUBSTR(m1.mensaje, INSTR(m1.mensaje, '"fecha":"') + 9, 17) AS INTEGER)
  WHERE m1.para = ?
  ORDER BY CAST(SUBSTR(m1.mensaje, INSTR(m1.mensaje, '"fecha":"') + 9, 17) AS INTEGER) DESC
  LIMIT ?
''', [usuarioActual, limit]);
      debugPrint('[DBProvider] Found ${dataList.length} group messages');
      int i = 0;
      _mensaje = dataList.map((item) {
        var fecha = jsonDecode(item['mensaje'].toString())["fecha"];
        DateTime parsedDate = DateTime(
          int.parse(fecha.substring(0, 4)),
          int.parse(fecha.substring(4, 6)),
          int.parse(fecha.substring(6, 8)),
          int.parse(fecha.substring(8, 10)),
          int.parse(fecha.substring(10, 12)),
          int.parse(fecha.substring(12, 14)),
          int.parse(fecha.substring(14, 17)),
        );
        i = i + 1;
        return Mensaje(
          de: item['de'].toString(),
          para: item['para'].toString(),
          mensaje: item['mensaje'].toString(),
          createdAt: item['createdAt'].toString(),
          updatedAt: item['updatedAt'].toString(),
          deleted: item['deleted'] == 1 ? true : false,
          incognito: 0,
          enviado: int.parse(item['enviado'].toString()),
          recibido: int.parse(item['recibido'].toString()),
          nombreEmisor: item['nombreEmisor'].toString(),
          parentContent: item['parentContent'].toString(),
          parentSender: item['parentSender'].toString(),
          isReply: int.parse(item['reply'].toString()) == 1 ? true : false,
          forwarded:
              int.parse(item['forwarded'].toString()) == 1 ? true : false,
          parentType: item['parentType'].toString(),
        );
      }).toList();
      return _mensaje;
    } else {
      // For personal messages: filter by both users being involved
      final dataList = await db.rawQuery('''
  SELECT m1.*, m2.mensaje AS parentMensaje
  FROM mensajes m1
  LEFT JOIN mensajes m2
  ON m1.parentContent = CAST(SUBSTR(m1.mensaje, INSTR(m1.mensaje, '"fecha":"') + 9, 17) AS INTEGER)
  WHERE ((m1.de = ? AND m1.para = ?) OR (m1.de = ? AND m1.para = ?))
  ORDER BY CAST(SUBSTR(m1.mensaje, INSTR(m1.mensaje, '"fecha":"') + 9, 17) AS INTEGER) DESC
  LIMIT ?
''', [currentUserId, usuarioActual, usuarioActual, currentUserId, limit]);
      // //print(
      //     "{msg dataList ➡️❌➡️❌➡️❌➡️❌➡️❌➡️❌➡️❌➡️❌➡️❌➡️❌➡️❌➡️❌➡️❌➡️❌➡️❌: ${dataList} ==}");
      int i = 0;
      _mensaje = dataList.map((item) {
        var fecha = jsonDecode(item['mensaje'].toString())["fecha"];
        DateTime parsedDate = DateTime(
          int.parse(fecha.substring(0, 4)),
          int.parse(fecha.substring(4, 6)),
          int.parse(fecha.substring(6, 8)),
          int.parse(fecha.substring(8, 10)),
          int.parse(fecha.substring(10, 12)),
          int.parse(fecha.substring(12, 14)),
          int.parse(fecha.substring(14, 17)),
        );
        // //print(
        //     "{==============msg : ${i} , fecha : ${parsedDate} ================}");
        i = i + 1;
        return Mensaje(
          de: item['de'].toString(),
          para: item['para'].toString(),
          mensaje: item['mensaje'].toString(),
          createdAt: item['createdAt'].toString(),
          updatedAt: item['updatedAt'].toString(),
          deleted: item['deleted'] == 1 ? true : false,
          incognito: 0,
          enviado: int.parse(item['enviado'].toString()),
          recibido: int.parse(item['recibido'].toString()),
          nombreEmisor: item['nombreEmisor'].toString(),
          parentContent: item['parentContent'].toString(),
          parentSender: item['parentSender'].toString(),
          isReply: int.parse(item['reply'].toString()) == 1 ? true : false,
          forwarded:
              int.parse(item['forwarded'].toString()) == 1 ? true : false,
          parentType: item['parentType'].toString(),
        );
      }).toList();
      return _mensaje;
    }
  }

  Future<List<Mensaje>> getTodosMensajes(
    usuarioActual,
  ) async {
    final db = await database;
    final dataList = await db.query(
      'mensajes',
      where: 'para=? OR de=?',
      whereArgs: [usuarioActual, usuarioActual],
      orderBy:
          "CAST(SUBSTR(mensaje, INSTR(mensaje, '\"fecha\":\"') + 9, 17) AS INTEGER) DESC",
    );
    _mensaje = dataList.map((item) {
      return Mensaje(
        deleted: item['deleted'] == 1 ? true : false,
        de: item['de'].toString(),
        para: item['para'].toString(),
        mensaje: item['mensaje'].toString(),
        createdAt: item['createdAt'].toString(),
        updatedAt: item['updatedAt'].toString(),
        incognito: 0,
        enviado: int.parse(item['enviado'].toString()),
        recibido: int.parse(item['recibido'].toString()),
        nombreEmisor: item['nombreEmisor'].toString(),
        parentContent: item['parentContent'].toString(),
        parentSender: item['parentSender'].toString(),
        isReply: int.parse(item['reply'].toString()) == 1 ? true : false,
        forwarded: int.parse(item['forwarded'].toString()) == 1 ? true : false,
        parentType: item['parentType'].toString(),
      );
    }).toList();
    return _mensaje;
  }

  void fetchDataAndUpdateStream(x) async {
    // final db = await database;

    _controller.add(x);
  }

  // Stream<List<Mensaje>> getDataAsStream(usuarioActual) {
  //   _database == null ? _database = initDB() : null;

  //   return _database!
  //       .query(
  //         'mensajes',
  //         where: 'para=? OR de=?',
  //         whereArgs: [usuarioActual, usuarioActual],
  //         orderBy: "createdAt DESC",
  //       )
  //       .asStream()
  //       .map((rows) => rows
  //           .map((row) => Mensaje(
  //                 de: row['de'].toString(),
  //                 para: row['para'].toString(),
  //                 mensaje: row['mensaje'].toString(),
  //                 createdAt: row['createdAt'].toString(),
  //                 updatedAt: row['updatedAt'].toString(),
  //                 incognito: 0,
  //                 enviado: int.parse(row['enviado'].toString()),
  //                 recibido: int.parse(row['recibido'].toString()),
  //                 nombreEmisor: row['nombreEmisor'].toString(),
  //                 parentContent: row['parentContent'].toString(),
  //                 parentSender: row['parentSender'].toString(),
  //                 isReply:
  //                     int.parse(row['reply'].toString()) == 1 ? true : false,
  //                 forwarded: int.parse(row['forwarded'].toString()) == 1
  //                     ? true
  //                     : false,
  //                 parentType: row['parentType'].toString(),
  //               ))
  //           .toList());
  // }

  Future<List<Mensaje>> getmensajes(String currentUserId) async {
    final db = await database;
    final dataList = await db.rawQuery(
        'SELECT rowid, * FROM mensajes WHERE de = ? OR para = ?',
        [currentUserId, currentUserId]);
    _mensaje = dataList
        .map(
          (item) => Mensaje(
            deleted: item['deleted'] == 1 ? true : false,
            de: item['de'].toString(),
            para: item['para'].toString(),
            mensaje: item['mensaje'].toString(),
            createdAt: item['createdAt'].toString(),
            updatedAt: item['updatedAt'].toString(),
            parentContent: item['parentContent'].toString(),
            parentSender: item['parentSender'].toString(),
            isReply: int.parse(item['reply'].toString()) == 1 ? true : false,
            forwarded:
                int.parse(item['forwarded'].toString()) == 1 ? true : false,
            parentType: item['parentType'].toString(),
          ),
        )
        .toList();
    return _mensaje;
  }

  Future<List<Usuario>> getcontactos() async {
    final db = await database;
    final dataList =
        await db.rawQuery('SELECT * FROM contactos ORDER BY nombre ASC');
    _usuario = dataList
        .map(
          (item) => Usuario(
            nombre: item['nombre'].toString(),
            online: item['online'] != null
                ? int.parse(item['online'].toString()) == 1
                    ? true
                    : false
                : false,
            avatar: item['avatar'].toString(),
            email: item['email'].toString(),
            codigoContacto: item['codigoContacto'].toString(),
            uid: item['uid'].toString(),
            publicKey: item['publicKey'].toString(),
            lastSeen:
                item['online'] != null ? item['lastSeen'].toString() : null,
          ),
        )
        .toList();
    return _usuario;
  }

  Future<List<UsuarioMensaje>> getUsuarioMensajeEsp(
      String currentUserId) async {
    final db = await database;
    var sql = ' ';

    // CRITICAL FIX: Include group messages where m.uid is a group code
    sql += 'SELECT m.*, c.*, g.*, c.nombre AS nombreContacto, '
        '     c.avatar AS avatarContacto, c.publicKey AS publickeyContacto, '
        '     g.nombre AS nombreGrupo, g.avatar AS avatarGrupo, g.fecha AS fechaGrupo '
        '   FROM mensajes m '
        '   LEFT JOIN contactos c ON c.uid = m.uid '
        '   LEFT JOIN grupos g ON g.codigo = m.uid '
        '   WHERE ( '
        '     (m.de = ? OR m.para = ?) ' // Personal messages
        '     OR g.codigo IS NOT NULL ' // Group messages
        '   ) '
        '   AND NOT (m.de = ? AND m.para = ?) ' // CRITICAL: Exclude self-chats
        '   AND (c.especial = 1 OR g.especial = 1) '
        '   AND (m.uid != ? OR g.codigo IS NOT NULL)'; // CRITICAL: Exclude if uid is current user (unless it's a group)

    final dataList = await db.rawQuery(sql, [
      currentUserId,
      currentUserId,
      currentUserId,
      currentUserId,
      currentUserId
    ]);

    _usuarioMensaje = dataList
        .map(
          (item) => UsuarioMensaje(
            nombre: item['nombreContacto'] != null
                ? item['nombreContacto'].toString()
                : item['nombreGrupo'].toString(),
            avatar: item['avatarContacto'] != null
                ? item['avatarContacto'].toString()
                : item['avatarGrupo'].toString(),
            uid: item['uid'] != null
                ? item['uid'].toString()
                : item['codigo'].toString(),
            email: item['email'] != null
                ? item['email'].toString()
                : item['descripcion'].toString(),
            online: item['online'].toString(),
            codigoContacto: item['codigoContacto'] != null
                ? item['codigoContacto'].toString()
                : item['fechaGrupo'].toString(),
            publicKey: item['publickeyContacto'].toString(),
            usuarioCrea: item['usuarioCrea'].toString(),
            mensaje: item['mensaje'].toString(),
            fecha: item['createdAt'].toString(),
            esGrupo: item['usuarioCrea'] != null ? 1 : 0,
          ),
        )
        .toList();

    UsuarioMensaje temp;

    for (var i = 0; i < _usuarioMensaje.length; i++) {
      for (var j = 1; j < (_usuarioMensaje.length - i); j++) {
        var value1 = DateTime.parse('${_usuarioMensaje[j - 1].fecha!}Z');
        var value2 = DateTime.parse('${_usuarioMensaje[j].fecha!}Z');
        if (value1.compareTo(value2) < 0) {
          temp = _usuarioMensaje[j - 1];
          _usuarioMensaje[j - 1] = _usuarioMensaje[j];
          _usuarioMensaje[j] = temp;
        }
      }
    }

    List group = [];
    List<UsuarioMensaje> nuevo = [];
    for (var m in _usuarioMensaje) {
      if (!group.contains(m.uid)) {
        group.add(m.uid);
        nuevo.add(m);
      }
    }

    return nuevo;
  }

  Future<List<UsuarioMensaje>> getUsuarioMensaje(String currentUserId) async {
    final db = await database;
    var sql = ' ';

    // CRITICAL FIX: Include group messages where m.uid is a group code
    // For personal messages: m.de or m.para is currentUserId
    // For group messages: m.uid (= m.para = group code) exists in grupos table
    //   - Backend sends group messages with de=sender, para=groupCode
    //   - So we need to match on g.codigo IS NOT NULL (meaning m.uid is a group)
    sql += 'SELECT m.*, c.*, g.*, c.nombre AS nombreContacto, '
        '     c.avatar AS avatarContacto, c.publicKey AS publickeyContacto, '
        '     g.nombre AS nombreGrupo, g.avatar AS avatarGrupo, g.publicKey, g.privateKey, g.fecha AS fechaGrupo '
        '   FROM mensajes m '
        '   LEFT JOIN contactos c ON c.uid = m.uid '
        '   LEFT JOIN grupos g ON g.codigo = m.uid '
        '   WHERE ( '
        '     (m.de = ? OR m.para = ?) ' // Personal messages
        '     OR g.codigo IS NOT NULL ' // Group messages (m.uid is a group code)
        '   ) '
        '   AND NOT (m.de = ? AND m.para = ?) ' // CRITICAL: Exclude self-chats
        '   AND (c.especial = 0 OR g.especial = 0 OR (c.especial IS NULL AND g.especial IS NULL)) '
        '   AND (c.deleted = 0 OR c.deleted IS NULL) '
        '   AND (m.uid != ? OR g.codigo IS NOT NULL) ' // CRITICAL: Exclude if uid is current user (unless it's a group)
        '   AND CAST(SUBSTR(m.mensaje, INSTR(m.mensaje, \'"fecha":"\') + 9, 17) AS INTEGER) = ( '
        '       SELECT MAX(CAST(SUBSTR(m2.mensaje, INSTR(m2.mensaje, \'"fecha":"\') + 9, 17) AS INTEGER)) '
        '       FROM mensajes m2 '
        '       WHERE m2.uid = m.uid '
        '   ) '
        '   GROUP BY m.uid '
        '   ORDER BY CAST(SUBSTR(m.mensaje, INSTR(m.mensaje, \'"fecha":"\') + 9, 17) AS INTEGER) DESC';

    final dataList = await db.rawQuery(sql, [
      currentUserId, // m.de = ?
      currentUserId, // m.para = ?
      currentUserId, // NOT (m.de = ?)
      currentUserId, // AND m.para = ?)
      currentUserId, // m.uid != ?
    ]);
    //print("---------------getUsuarioMensaje-------------");
    //print("---------------${dataList}-------------");

    //print("----------------------------------------------");
    _usuarioMensaje = dataList
        .map(
          (item) => UsuarioMensaje(
            nombre: item['nombreContacto'] != null
                ? item['nombreContacto'].toString()
                : item['nombreGrupo'].toString(),
            avatar: item['avatarContacto'] != null
                ? item['avatarContacto'].toString()
                : item['avatarGrupo'].toString(),
            uid: item['uid'] != null
                ? item['uid'].toString()
                : item['codigo'].toString(),
            email: item['email'] != null
                ? item['email'].toString()
                : item['descripcion'].toString(),
            online: item['online'].toString(),
            codigoContacto: item['codigoContacto'] != null
                ? item['codigoContacto'].toString()
                : item['fechaGrupo'].toString(),
            usuarioCrea: item['usuarioCrea'].toString(),
            mensaje: item['mensaje'].toString(),
            publicKey: item['publickeyContacto'] != null
                ? item['publickeyContacto'].toString()
                : item['publicKey'].toString(),
            privateKey: item['privateKey'].toString(),
            fecha: item['createdAt'].toString(),
            deleted: item['deleted'] == 1 ? true : false,
            lastSeen: item['lastSeen']?.toString(),
            esGrupo: item['usuarioCrea'] != null ? 1 : 0,
          ),
        )
        .toList();
/* 
    var temp;

    for (var i = 0; i < _usuarioMensaje.length; i++) {
      for (var j = 1; j < (_usuarioMensaje.length - i); j++) {
        var value1 = DateTime.parse(_usuarioMensaje[j - 1].fecha! + 'Z');
        var value2 = DateTime.parse(_usuarioMensaje[j].fecha! + 'Z');
        if (value1.compareTo(value2) < 0) {
          temp = _usuarioMensaje[j - 1];
          _usuarioMensaje[j - 1] = _usuarioMensaje[j];
          _usuarioMensaje[j] = temp;
        }
      }
    }

    */

    List group = [];
    List<UsuarioMensaje> nuevo = [];
    for (var m in _usuarioMensaje) {
      if (!group.contains(m.uid)) {
        group.add(m.uid);
        nuevo.add(m);
      }
    }

    return _usuarioMensaje;
  }

  Future<List<Mensaje>> getArchivosUsuario(
      type, usuarioActual, currentUserId) async {
    final db = await database;

    const sql = 'SELECT * FROM mensajes '
        'WHERE mensaje LIKE ? AND ((de = ? AND para = ?) OR (de = ? AND para = ?))';
    final dataList = await db.rawQuery(sql, [
      '%$type%',
      currentUserId,
      usuarioActual,
      usuarioActual,
      currentUserId
    ]);
    _mensaje = dataList.map((item) {
      return Mensaje(
        deleted: item['deleted'] == 1 ? true : false,
        de: item['de'].toString(),
        para: item['para'].toString(),
        mensaje: item['mensaje'].toString(),
        createdAt: item['createdAt'].toString(),
        updatedAt: item['updatedAt'].toString(),
      );
    }).toList();

    return _mensaje;
  }

  getDataDB() async {
    final db = await database;
    final m = await db.query('mensajes');
    final c = await db.query('contactos');
    final g = await db.query('grupos');

    var cantidad = {
      'mensaje': m.length,
      'contacto': c.length,
      'grupo': g.length,
    };
    return cantidad;
  }

  updateContactos(uid, String column, value) async {
    if (column == 'incognito') {
      value = value ? 1 : 0;
    }
    final db = await database;
    final res = await db.rawUpdate('UPDATE contactos '
        'SET $column = $value '
        'WHERE uid = "$uid"');
    return res;
  }

  updateGrupo(codigo, String column, value) async {
    final db = await database;
    final res = await db.rawUpdate('UPDATE grupos '
        'SET $column = $value '
        'WHERE codigo = "$codigo"');
    return res;
  }

  borrarContacto(contacto) async {
    final db = await database;
    // Soft delete: Mark as deleted instead of actually deleting
    final res = await db.update(
      'contactos',
      {'deleted': 1},
      where: 'uid = ?',
      whereArgs: [contacto],
    );
    return res;
  }

  esContacto(contacto, {String tipo = 'usuario'}) async {
    Object? res;
    final db = await database;
    if (tipo == "usuario") {
      final find = await db.query(
        'contactos',
        columns: ['incognito'],
        where: 'uid=?',
        whereArgs: [contacto],
      );
      if (find.isNotEmpty) res = find.first['incognito'];
    } else if (tipo == "grupo") {
      // final find = await db.query(
      //   'grupos',
      //   where: 'codigo=?',
      //   whereArgs: [contacto],
      // );
      final find = await db.query('grupousuario',
          where: 'codigoGrupo = ? ', whereArgs: [contacto]);
      res = find.length;
      if (res == 0) {
        db.delete('grupos', where: 'codigo', whereArgs: [contacto]);
      }
    }

    return res;
  }

  eliminarIncognitos(usuarioUID) async {
    final db = await database;
    final res = await db.delete(
      'mensajes',
      where: 'incognito=1 and (de = ? or para= ?)',
      whereArgs: [usuarioUID, usuarioUID],
    );
    return res;
  }

  getPagos() async {
    final db = await database;
    var res = await db.rawQuery("SELECT * FROM pagos ORDER BY fecha DESC");
    pagos = res
        .map(
          (item) => ObjPago(
            nombre: item["nombre"].toString(),
            valor: item["valor"].toString(),
            fecha: item["fecha"].toString(),
            fechaPago: item["fechaPago"].toString(),
          ),
        )
        .toList();
    return pagos;
  }

  insertarPago(ObjPago pago) async {
    final db = await database;
    final res = db.insert("pagos", pago.toJson());
    return res;
  }

  borrarPagos() async {
    final db = await database;
    await db.delete('pagos');
  }

  /// Check if a code is a group code (exists in grupos table)
  /// Used to detect group messages when backend doesn't send grupo object
  Future<bool> isGroupCode(String code) async {
    if (code.isEmpty) return false;
    final db = await database;
    final result = await db.query(
      'grupos',
      where: 'codigo = ?',
      whereArgs: [code],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<List<Grupo>> getGrupos() async {
    final db = await database;
    final list = await db.query('grupos');

    _grupo = list
        .map((item) => Grupo(
            codigo: item['codigo'].toString(),
            nombre: item['nombre'].toString(),
            descripcion: item['descripcion'].toString(),
            avatar: item['avatar'].toString(),
            publicKey: item['publicKey'].toString(),
            privateKey: item['privateKey'].toString(),
            usuarioCrea: item['usuarioCrea'].toString(),
            fecha: item['fecha'].toString()))
        .toList();

    return _grupo;
  }

  Future<List<GrupoUsuario>> getMiembrosGroup(codigo) async {
    final db = await database;
    final list = await db.query(
      'grupousuario',
      where: 'codigoGrupo = ?',
      whereArgs: [codigo],
    );
    _grupousuario = list
        .map((e) => GrupoUsuario(
              codigoGrupo: e['codigoGrupo'].toString(),
              uidUsuario: e['uidUsuario'].toString(),
              codigoUsuario: e['codigoUsuario'].toString(),
              avatarUsuario: e['avatarUsuario'].toString(),
              nombreUsuario: e['nombreUsuario'].toString(),
            ))
        .toList();
    return _grupousuario;
  }

  deleteMiembro(codigoGrupo, codigoUsuario) async {
    final db = await database;
    final res = await db.delete('grupousuario',
        where: 'codigoGrupo = ? AND uidUsuario = ? ',
        whereArgs: [codigoGrupo, codigoUsuario]);
    //print('Delete miembro: ' + res.toString());
  }

  deleteGroup(codigo) async {
    final db = await database;
    final m = await db.delete('mensajes', where: 'uid=?', whereArgs: [codigo]);
    final g = await db.delete('grupos', where: 'codigo=?', whereArgs: [codigo]);
    final gu = await db.delete(
      'grupousuario',
      where: 'codigoGrupo=?',
      whereArgs: [codigo],
    );
  }
}
