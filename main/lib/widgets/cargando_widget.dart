import 'package:flutter/material.dart';
import 'package:CryptoChat/helpers/style.dart';

class CargandoeEstado extends StatefulWidget {
  final double carga;

  const CargandoeEstado({super.key, 
    required this.carga,
  });

  @override
  _CargandoeEstadoState createState() => _CargandoeEstadoState();
}

class _CargandoeEstadoState extends State<CargandoeEstado> {
  late double _value;
  @override
  void initState() {
    _value = widget.carga;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return LinearProgressIndicator(
      value: _value,
      backgroundColor: amarillo,
      valueColor: AlwaysStoppedAnimation(verde),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
