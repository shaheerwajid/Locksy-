import 'package:flutter/material.dart';
import 'package:CryptoChat/calc/display.dart';
import 'package:CryptoChat/calc/key-controller.dart';
import 'package:CryptoChat/calc/key-pad.dart';
import 'package:CryptoChat/calc/processor.dart';

class Calculator extends StatefulWidget {
  const Calculator({Key? key}) : super(key: key);

  @override
  _CalculatorState createState() => _CalculatorState();
}

class _CalculatorState extends State<Calculator> {
  late String _output;

  @override
  void initState() {
    KeyController.listen((event) => Processor.process(event));
    Processor.listen((data) => setState(() {
          _output = data;
        }));
    Processor.refresh();
    super.initState();
  }

  @override
  void dispose() {
    KeyController.dispose();
    Processor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Size screen = MediaQuery.of(context).size;

    double buttonSize = screen.width / 4;
    double displayHeight = screen.height - (buttonSize * 5) - (buttonSize);

    return Scaffold(
      backgroundColor: const Color.fromARGB(196, 32, 64, 96),
      body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Display(value: _output, height: displayHeight),
            const KeyPad()
          ]),
    );
  }
}
