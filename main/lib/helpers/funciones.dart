import 'dart:io';
import 'dart:math';

import 'package:date_format/date_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:CryptoChat/helpers/style.dart';

/*
  * Funcion para Obtener Color en Hex
  * @author Jhoan Silva
  * @since 2021/03/24
  * @retunr Color 
*/
Color _getColorFromHex(String hexColor) {
  Color? color;
  hexColor = hexColor.replaceAll("#", "");
  if (hexColor.length == 6) {
    hexColor = "FF$hexColor";
  }
  if (hexColor.length == 8) {
    color = Color(int.parse("0x$hexColor"));
  }
  return color!;
}

Color prueba = _getColorFromHex('a');

/*
  * Funcion para Capitalizar textos
  * @author Jhoan Silva
  * @since 2021/03/24
  * @return String
*/
String capitalize(String string) {
  String res = "";

  if (string.isEmpty) {
    return res;
  }

  List<String> nombre = string.trim().split(' ');
  for (int i = 0; i < nombre.length; i++) {
    res += "${nombre[i][0].toUpperCase()}${nombre[i].substring(1)} ";
  }
  return res;
}

/*
  * Funcion para mostrar vista previa del Historial de Chats
  * @author Jhoan Silva
  * @since 2021/03/24
  * @return String
*/
String getMessageText(String tipo, String text) {
  switch (tipo) {
    case 'recording':
      return 'Audio';
      break;
    case 'audio':
      return 'Audio';
      break;
    case 'images':
      return 'Img';
      break;
    case 'video':
      return 'Video';
      break;
    case 'documents':
      return 'Doc';
      break;
    case 'text':
      var cant = text.length;
      return cant > 25 ? text.substring(0, 25) : text;
      break;
    case 'system':
      return '...';
      break;
  }
  return 'Default';
}

/*
  * Funcion para mostrar icono previo en Historial de Chats
  * @author Jhoan Silva
  * @since 2021/03/24
  * @return Widget
*/
Widget? getIconMsg(String tipo) {
  switch (tipo) {
    case 'recording':
      return Icon(
        Icons.mic,
        color: gris,
      );
      break;
    case 'audio':
      return Icon(
        Icons.music_note_rounded,
        color: gris,
      );
      break;
    case 'images':
      return Icon(
        Icons.image,
        color: gris,
      );
      break;
    case 'video':
      return Icon(
        Icons.play_circle_filled_rounded,
        color: gris,
      );
      break;
    case 'documents':
      return Icon(
        Icons.attach_file_outlined,
        color: gris,
      );
      break;
    case 'text':
      return null;
      break;
  }
  return null;
}

/*
  * Funcion para generar Codigo de Contacto
  * @author Jhoan Silva
  * @since 2021/03/24
  * @return String
*/
String generateCode() {
  String generateNum() {
    var ramdom = Random.secure();
    int rng = ramdom.nextInt(9);
    return '$rng';
  }

  String generateStr() {
    var ramdom = Random.secure();
    String letras = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    var cant = letras.length;
    int rng = ramdom.nextInt(cant - 1);
    String script = letras.substring(rng, rng + 1);
    return script;
  }

  String cadena1 = generateStr() + generateNum() + generateStr();
  String cadena2 = generateNum() + generateStr() + generateNum();
  String cadena3 = generateStr() + generateNum() + generateStr();

  String code = '$cadena1-$cadena2-$cadena3';
  if (code == "A1B-2C3-D4E") {
    code = generateCode();
  }
//'A1B-2C3-D4E'
  return code;
}

/*
  * Funcion para separar un texto mediante "-" cada 3 caracteres
  * @author Jhoan Silva
  * @since 2021/03/24
  * @return String
*/
String addSeparator(String code) {
  String str;
  str = code.replaceAll('-', '');
  var array = str.split('');
  str = '${array[0]}${array[1]}${array[2]}-${array[3]}${array[4]}${array[5]}-${array[6]}${array[7]}${array[8]}';
  return str;
}

/*
  * Funcion para obtener fecha actual sin separadores
  * @author Jhoan Silva
  * @since 2021/03/24
  * @return String
*/
String deconstruirDateTime() {
  var now = DateTime.now().toUtc();

  var year = now.year;
  var month = now.month < 10 ? '0${now.month}' : now.month;
  var day = now.day < 10 ? '0${now.day}' : now.day;
  var hour = now.hour < 10 ? '0${now.hour}' : now.hour;
  var min = now.minute < 10 ? '0${now.minute}' : now.minute;
  var sec = now.second < 10 ? '0${now.second}' : now.second;
  var millisecond = now.millisecond < 100
      ? (now.millisecond < 10 ? '00${now.millisecond}' : '0${now.millisecond}')
      : now.millisecond;
  String fecha = '$year$month$day$hour$min$sec$millisecond';
  return fecha;
}

String deconstruirLoclDateTime() {
  var now = DateTime.now().toLocal();

  var year = now.year;
  var month = now.month < 10 ? '0${now.month}' : now.month;
  var day = now.day < 10 ? '0${now.day}' : now.day;
  var hour = now.hour < 10 ? '0${now.hour}' : now.hour;
  var min = now.minute < 10 ? '0${now.minute}' : now.minute;
  var sec = now.second < 10 ? '0${now.second}' : now.second;
  var millisecond = now.millisecond < 100
      ? (now.millisecond < 10 ? '00${now.millisecond}' : '0${now.millisecond}')
      : now.millisecond;
  String fecha = '$year$month$day$hour$min$sec$millisecond';
  return fecha;
}

/*
  * Funcion para convertir DateTime a String
  * @author Jhoan Silva
  * @since 2021/03/24
  * @return String
*/
String formatHour(DateTime fecha) {
  var hour = fecha.hour > 12 ? fecha.hour - 12 : fecha.hour;
  var minute = fecha.minute;
  var am = fecha.hour > 12 ? 'pm' : 'am';
  String hora = '$hour:$minute $am';
  return hora;
}

/*
  * Funcion para convertir Duration a String
  * @author Jhoan Silva
  * @since 2021/03/24
  * @return String
*/
String formatTiempo(Duration tiempo) {
  String valor = '0000-00-00 0$tiempo';
  var fecha = DateTime.parse(valor);
  var duracion = formatDate(fecha, [nn, ':', ss]);
  return duracion.toString();
}

/*
  * Funcion para convertir un String a File 
  * @author Jhoan Silva
  * @since 2021/03/24
  * @return File
*/
File strtoFile(String path) {
  final file = File(path);
  return file;
}

XFile strtoFile1(String path) {
  final file = XFile(path);
  return file;
}

/*
  * Funcion para construir la ubicacion de los Avatars 
  * @author Jhoan Silva
  * @since 2021/03/26
  * @return String
*/
String getAvatar(String avatar, String tipo) {
  return 'assets/icon/$tipo$avatar';
}
// String pathAvatar(String avatar, String folder) {
//   final path = '${Environment.socketUrl}/$folder/';
//   return path + avatar;
// }

/*
  * Función para el cifrado de textos
  * @author Deyner Reinoso
  * @since 2021/03/24
  * @return String
*/
String cifrarPMS(String text) {
  String res = "";
  res = text;
  return res;
}

/*
  * Función para el decifrado de textos
  * @author Deyner Reinoso
  * @since 2021/03/24
  * @return String
*/
String decifrarPMS(String text) {
  String res = "";
  res = text;
  return res;
}

/*
  * Función para traducir textos
  * @author Deyner Reinoso
  * @since 2021/03/24
  * @return String
*/
String translateString(String text) {
  String res = "";
  res = text;
  return res;
}

/*
  * Funcion para validar un correo electronico 
  * @author Deyner Reinoso
  * @since 2021/03/26
  * @return String
*/
bool validateEmail(String value) {
  String pattern =
      r'^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$';
  RegExp regex = RegExp(pattern);
  return (!regex.hasMatch(value)) ? false : true;
}

/*
  * Funcion para crear URl 
  * @author Deyner Reinoso
  * @since 2021/03/26
  * @return String
*/
String crearURl(String texto) {
  // print(texto);
  var copia = texto;
  texto = texto.replaceAll(RegExp('http:|https:|//'), '');

  List<String> dominios = [
    'ac',
    'ad',
    'ae',
    'af',
    'ag',
    'ai',
    'al',
    'am',
    'an',
    'ao',
    'aq',
    'ar',
    'as',
    'at',
    'au',
    'aw',
    'ax',
    'az',
    'ba',
    'bb',
    'bd',
    'be',
    'bf',
    'bg',
    'bh',
    'bi',
    'bj',
    'bl',
    'bm',
    'bn',
    'bo',
    'br',
    'bq',
    'bs',
    'bt',
    'bv',
    'bw',
    'by',
    'bz',
    'ca',
    'cc',
    'cd',
    'cf',
    'cg',
    'ch',
    'ci',
    'ck',
    'cl',
    'cm',
    'cn',
    'co',
    'cr',
    'cs',
    'cu',
    'cv',
    'cw',
    'cx',
    'cy',
    'cz',
    'dd',
    'de',
    'dj',
    'dk',
    'dm',
    'do',
    'dz',
    'ec',
    'ee',
    'eg',
    'eh',
    'er',
    'es',
    'et',
    'eu',
    'fi',
    'fj',
    'fk',
    'fm',
    'fo',
    'fr',
    'ga',
    'gb',
    'gd',
    'ge',
    'gf',
    'gg',
    'gh',
    'gi',
    'gl',
    'gm',
    'gn',
    'gp',
    'gq',
    'gr',
    'gs',
    'gt',
    'gu',
    'gw',
    'gy',
    'hk',
    'hm',
    'hn',
    'hr',
    'ht',
    'hu',
    'id',
    'ie',
    'il',
    'im',
    'in',
    'io',
    'iq',
    'ir',
    'is',
    'it',
    'je',
    'jm',
    'jo',
    'jp',
    'ke',
    'kg',
    'kh',
    'ki',
    'km',
    'kn',
    'kp',
    'kr',
    'kw',
    'ky',
    'kz',
    'la',
    'lb',
    'lc',
    'li',
    'lk',
    'lr',
    'ls',
    'lt',
    'lu',
    'lv',
    'ly',
    'ma',
    'mc',
    'md',
    'me',
    'mf',
    'mg',
    'mh',
    'mk',
    'ml',
    'mm',
    'mn',
    'mo',
    'mp',
    'mq',
    'mr',
    'ms',
    'mt',
    'mu',
    'mv',
    'mw',
    'mx',
    'my',
    'mz',
    'na',
    'nc',
    'ne',
    'nf',
    'ng',
    'ni',
    'nl',
    'no',
    'np',
    'nr',
    'nu',
    'nz',
    'om',
    'pa',
    'pe',
    'pf',
    'pg',
    'ph',
    'pk',
    'pl',
    'pm',
    'pn',
    'pr',
    'ps',
    'pt',
    'pw',
    'py',
    'qa',
    're',
    'ro',
    'rs',
    'ru',
    'rw',
    'sa',
    'sb',
    'sc',
    'sd',
    'se',
    'sg',
    'sh',
    'si',
    'sj',
    'sk',
    'sl',
    'sm',
    'sn',
    'so',
    'sr',
    'ss',
    'st',
    'su',
    'sv',
    'sx',
    'sy',
    'sz',
    'tc',
    'td',
    'tf',
    'tg',
    'th',
    'tj',
    'tk',
    'tl',
    'tm',
    'tn',
    'to',
    'tp',
    'tr',
    'tt',
    'tv',
    'tw',
    'tz',
    'ua',
    'ug',
    'uk',
    'um',
    'us',
    'uy',
    'uz',
    'va',
    'vc',
    've',
    'vg',
    'vi',
    'vn',
    'vu',
    'wf',
    'ws',
    'ye',
    'yt',
    'yu',
    'za',
    'zm',
    'zr',
    'zw',
    'com',
    'org',
    'net',
    'name',
    'io',
    'edu',
    'gov',
    'mil',
    'xxx',
    'xyz',
    'tech',
    'pro',
    'shop',
    'top',
    'info',
    'systems'
  ];
  String txt;
  String url = 'http://';
  bool existe;
  var array = texto.split('.');
  if (array.length > 1) {
    txt = array[array.length - 1];
    existe = dominios.contains(txt);
    if (existe) {
      txt = url + texto;
    } else {
      txt = copia;
    }
  } else {
    txt = texto;
  }
  return txt;
}

String construirDateTime(String valor) {
  var array = valor.split('');
  String fecha = '';
  if (array.length > 13) {
    var year = array[0] + array[1] + array[2] + array[3];
    var month = array[4] + array[5];
    var day = array[6] + array[7];
    var hour = array[8] + array[9];
    var min = array[10] + array[11];
    var sec = array[12] + array[13];
    fecha = '$year-$month-$day $hour:$min:$sec';
  }
  return fecha;
}

String dateServerToClient(String valor, zona) {
  DateTime horaTotal;
  String fecha;
  var array = valor.split('.');
  var datazone = zona.split('');
  var horas = datazone[1] + datazone[2];

  valor = array[0].replaceAll('T', ' ');
  Duration recipientTimeZoneOffset = DateTime.now().timeZoneOffset;
  DateTime fecha1 = DateTime.parse(valor);

  if (datazone[0] == '-') {
    horaTotal = fecha1.subtract(Duration(hours: int.parse(horas)));
    horaTotal = horaTotal.toLocal().add(recipientTimeZoneOffset);
  } else {
    horaTotal = fecha1.add(Duration(hours: int.parse(horas)));
    horaTotal = horaTotal.toLocal().add(recipientTimeZoneOffset);
  }
  fecha = horaTotal.toString().split('.')[0];

  return fecha;
}

String replaceCharAt(String oldString, int index, String newChar) {
  return oldString.substring(0, index) +
      newChar +
      oldString.substring(index + 1);
}

Future compressImage(File file) async {
  // print("==file.lengthSync==");
  // print(file.lengthSync());
  final result = await FlutterImageCompress.compressWithFile(
    file.absolute.path,
    minWidth: 1280,
    minHeight: 960,
    quality: 60,
  );
  var memoryImage = MemoryImage(result!);
  return memoryImage;
}

dynamic compressVideo(File file) {
  // TO DO
}
