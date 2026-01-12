import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:CryptoChat/calc/calculator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const CalculatorApp());
}

class CalculatorApp extends StatelessWidget {
  const CalculatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(primarySwatch: Colors.teal),
      home: const Calculator(),
      debugShowCheckedModeBanner: false,
    );
  }
}
