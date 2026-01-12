import 'package:CryptoChat/calc/calculator-key.dart';

enum KeyType { FUNCTION, OPERATOR, INTEGER }

class KeySymbol {
  const KeySymbol(this.value);
  final String value;

  static final List<KeySymbol> _functions = [
    Keys.clear,
    Keys.sign,
    Keys.percent,
    Keys.decimal,
    // Keys.sqrt
  ];
  static final List<KeySymbol> _operators = [
    Keys.divide,
    Keys.multiply,
    Keys.subtract,
    Keys.add,
    Keys.equals,
  ];

  @override
  String toString() => value;

  bool get isOperator => _operators.contains(this);
  bool get isFunction => _functions.contains(this);
  bool get isInteger => !isOperator && !isFunction;

  KeyType get type => isFunction
      ? KeyType.FUNCTION
      : (isOperator ? KeyType.OPERATOR : KeyType.INTEGER);
}
