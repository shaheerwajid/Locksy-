import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:CryptoChat/global/AppLocalizations.dart';
import 'package:CryptoChat/helpers/style.dart';
import 'package:CryptoChat/widgets/mostrar_alerta.dart';
import 'package:CryptoChat/widgets/pinInput_widget.dart';

class OpcionesPage extends StatefulWidget {
  const OpcionesPage({super.key});

  @override
  _OpcionesPageState createState() => _OpcionesPageState();
}

class _OpcionesPageState extends State<OpcionesPage> {
  String? myPin;
  String? myCode;
  @override
  void initState() {
    _pinCryptoChat();
    _codeCryptoChat();
    super.initState();
  }

  _pinCryptoChat() async {
    var prefs = await SharedPreferences.getInstance();
    myPin = prefs.getString('CryptoChatPIN');
    setState(() {
      // print(this.myPin);
    });
  }

  _codeCryptoChat() async {
    var prefs = await SharedPreferences.getInstance();
    myCode = prefs.getString('PanicPIN');
    setState(() {
      // print(this.myCode);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: drawer_white,
        appBar: AppBar(
          shadowColor: drawer_light_white,
          backgroundColor: drawer_light_white,
          leading: InkWell(
            child: Icon(
              Icons.arrow_back_ios_rounded,
              color: gris,
            ),
            onTap: () => Navigator.pop(context),
          ),
          title: Text(
            AppLocalizations.of(context)!.translate('SECURITY_SETTINGS'),
            style: TextStyle(color: gris),
          ),
          centerTitle: true,
        ),
        body: ListView(
          children: [
            Card(
              child: ListTile(
                tileColor: chat_color,
                title: Text(AppLocalizations.of(context)!
                    .translate('SECURITY_QUESTIONS')),
                onTap: () => Navigator.pushNamed(context, 'preguntas'),
              ),
            ),
            Card(
              child: ListTile(
                tileColor: chat_color,
                title:
                    Text(AppLocalizations.of(context)!.translate('NINJA_PIN')),
                onTap: () {
                  myPin == null || myPin == ''
                      ? Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PinPutView(
                                titulo: 'NINJA_PIN',
                                subtitulo: 'DEFINE_NINJA_PIN'),
                          )).then((codigo) {
                          if (codigo != false) {
                            // print('El Ninja Pin es $codigo');
                            guardarPin(codigo);
                          }
                        })
                      : alertaConfirmar(
                              context,
                              AppLocalizations.of(context)!
                                  .translate('INFORMATION'),
                              AppLocalizations.of(context)!
                                  .translate('DELETE_NINJA_PIN'))
                          .then((res) {
                          if (res) {
                            cambiarPin();
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const PinPutView(
                                      titulo: 'NINJA_PIN',
                                      subtitulo: 'DEFINE_NINJA_PIN'),
                                )).then((codigo) {
                              if (codigo != false) {
                                // print('El Ninja Pin es $codigo');
                                guardarPin(codigo);
                              }
                            });
                          }
                        });
                },
              ),
            ),
            Card(
              child: ListTile(
                tileColor: chat_color,
                title: Text(
                  AppLocalizations.of(context)!.translate('PANIC_CODE'),
                ),
                onTap: () {
                  myCode == null || myCode == ''
                      ? Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PinPutView(
                              titulo: 'PANIC_CODE',
                              subtitulo: 'PANIC_DESC',
                            ),
                          )).then((codigo) {
                          if (codigo != false) {
                            // print('El codigo panico es $codigo');
                            guardarCode(codigo);
                          }
                        })
                      : alertaConfirmar(
                              context,
                              AppLocalizations.of(context)!
                                  .translate('INFORMATION'),
                              AppLocalizations.of(context)!
                                  .translate('DELETE_NINJA_PIN'))
                          .then((res) {
                          if (res) {
                            cambiarCode()();
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const PinPutView(
                                      titulo: 'PANIC_CODE',
                                      subtitulo: 'PANIC_DESC'),
                                )).then((codigo) {
                              if (codigo != false) {
                                // print('El codigo panico es $codigo');
                                guardarCode(codigo);
                              }
                            });
                          }
                        });
                },
              ),
            ),
          ],
        ));
  }

  guardarPin(pin) async {
    var prefs = await SharedPreferences.getInstance();
    await prefs.setString('CryptoChatPIN', pin);
    setState(() {
      myPin = pin;
    });
  }

  cambiarPin() async {
    var prefs = await SharedPreferences.getInstance();
    prefs.setString('CryptoChatPIN', '');
    setState(() {
      myPin = null;
    });
  }

  guardarCode(pin) async {
    var prefs = await SharedPreferences.getInstance();
    await prefs.setString('PanicPIN', pin);
    setState(() {
      myCode = pin;
    });
  }

  cambiarCode() async {
    var prefs = await SharedPreferences.getInstance();
    prefs.setString('PanicPIN', '');
    setState(() {
      myCode = null;
    });
  }
}
