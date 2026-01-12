import 'dart:async';
import 'dart:core';
import 'dart:io';

// Temporarily disabled - flutter_dynamic_icon incompatible with Flutter v2 embedding
// import 'package:flutter_dynamic_icon/flutter_dynamic_icon.dart';
import 'package:CryptoChat/calc/calculator-key.dart';
import 'package:CryptoChat/calc/key-controller.dart' as kc;
import 'package:CryptoChat/calc/key-symbol.dart';

// import 'package:flutter_icon_switcher/flutter_icon_switcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:CryptoChat/providers/db_provider.dart';

typedef StreamHandler<T> = void Function(T event);

abstract class Processor {
  static KeySymbol? _operator;
  static String _valA = '0';
  static String _valB = '0';
  static String? _result;

  static String? secretCode;
  static String? panicCode;

  static final StreamController _controller = StreamController();
  static Stream get _stream => _controller.stream;

  static StreamSubscription listen(void Function(dynamic)? handler) =>
      _stream.listen(handler);

  static void refresh() => _fire(_output!);

  static void _fire(String data) => _controller.add(_output);

  static String? get _output => _result ?? _equation;

  static String get _equation =>
      _valA +
      (_operator != null ? ' ${_operator!.value}' : '') +
      (_valB != '0' ? ' $_valB' : '');

  static dispose() => _controller.close();

  static process(dynamic event) {
    CalculatorKey key = (event as kc.KeyEvent).key;
    switch (key.symbol.type) {
      case KeyType.FUNCTION:
        return handleFunction(key);

      case KeyType.OPERATOR:
        return handleOperator(key);

      case KeyType.INTEGER:
        return handleInteger(key);
    }
  }

  static void handleFunction(CalculatorKey key) {
    if (_valA == '0') {
      return;
    }
    if (_result != null) {
      _condense();
    }

    Map<KeySymbol, dynamic> table = {
      Keys.clear: () => _clear(),
      Keys.sign: () => _sign(),
      Keys.percent: () => _percent(),
      Keys.decimal: () => _decimal(),
      // Keys.sqrt: () => _sqrt(),
    };

    table[key.symbol]();
    refresh();
  }

  static void handleOperator(CalculatorKey key) {
    if (_valA == '0') {
      return;
    }
    if (key.symbol == Keys.equals) {
      return _calculate();
    }
    if (_result != null) {
      _condense();
    }

    _operator = key.symbol;
    refresh();
  }

  static void handleInteger(CalculatorKey key) {
    String val = key.symbol.value;
    if (_operator == null) {
      _valA = (_valA == '0') ? val : _valA + val;
    } else {
      _valB = (_valB == '0') ? val : _valB + val;
      // _valB += val;
    }
    refresh();
  }

  static void _clear() {
    _valA = _valB = '0';
    _operator = _result = null;
  }

  static void _sign() {
    if (_valB != '0') {
      _valB = (_valB.contains('-') ? _valB.substring(1) : '-$_valB');
    } else if (_valA != '0') {
      _valA = (_valA.contains('-') ? _valA.substring(1) : '-$_valA');
    }
  }

  static String calcPercent(String x) => (double.parse(x) / 100).toString();

  static void _percent() {
    if (_valB != '0' && !_valB.contains('.')) {
      _valB = calcPercent(_valB);
    } else if (_valA != '0' && !_valA.contains('.')) {
      _valA = calcPercent(_valA);
    }
  }

  static void _decimal() {
    if (_valB != '0' && !_valB.contains('.')) {
      _valB = '$_valB.';
    } else if (_valA != '0' && !_valA.contains('.')) {
      _valA = '$_valA.';
    }
  }

  static Future changeInitialRoute(String ruta) async {
    var prefs = await SharedPreferences.getInstance();
    await prefs.setString('PMSInitialRoute', ruta);
    // print(prefs.getString('PMSInitialRoute'));
  }

  static Future<String?> getSecretCode() async {
    var prefs = await SharedPreferences.getInstance();
    return prefs.getString('CryptoChatPIN');
  }

  static Future<String?> getPanicCode() async {
    var prefs = await SharedPreferences.getInstance();
    return prefs.getString('PanicPIN');
  }

  static changeApp() async {
    if (Platform.isAndroid) {
      // FlutterIconSwitcher.updateIcon("MainActivity");
      //to replace
      exit(1);
    } else {
      try {
        // Temporarily disabled - flutter_dynamic_icon incompatible with Flutter v2 embedding
        // if (await FlutterDynamicIcon.supportsAlternateIcons) {
        //   await FlutterDynamicIcon.setAlternateIconName(null);
        //   // print("App icon change successful");
        //   exit(1);
        // }
        // Dynamic icon feature temporarily disabled - functionality preserved for future re-enablement
        exit(1);
      } catch (e) {
        // print(e);
      } finally {
        exit(0);
      }
    }
  }

  static void _calculate() async {
    secretCode = await getSecretCode();
    panicCode = await getPanicCode();
    if (_valA.length == 4 && secretCode == _valA) {
      changeInitialRoute("loading").then(
        (value) => changeApp(),
      );
    }
    if (_valA.length == 4 && panicCode == _valA) {
      changeInitialRoute("loading")
          .then((value) => DBProvider.db.borrarALL().then(
                (value) => changeApp(),
              ));
    }

    if (_operator == null || _valB == '0') {
      return;
    }

    Map<KeySymbol, dynamic> table = {
      Keys.divide: (a, b) => (a / b),
      Keys.multiply: (a, b) => (a * b),
      Keys.subtract: (a, b) => (a - b),
      Keys.add: (a, b) => (a + b)
    };

    double result = table[_operator](double.parse(_valA), double.parse(_valB));
    String str = result.toString();

    while ((str.contains('.') && str.endsWith('0')) || str.endsWith('.')) {
      str = str.substring(0, str.length - 1);
    }

    _result = str;
    refresh();
  }

  static void _condense() {
    _valA = _result!;
    _valB = '0';
    _result = _operator = null;
  }
}
