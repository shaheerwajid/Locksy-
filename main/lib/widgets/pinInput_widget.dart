import 'package:flutter/material.dart';
import 'package:CryptoChat/global/AppLocalizations.dart';
import 'package:CryptoChat/helpers/style.dart';
import 'package:CryptoChat/widgets/mostrar_alerta.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

class PinPutView extends StatefulWidget {
  final String titulo;
  final String subtitulo;
  const PinPutView({super.key, 
    required this.titulo,
    required this.subtitulo,
  });

  @override
  PinPutViewState createState() => PinPutViewState();
}

class PinPutViewState extends State<PinPutView> {
  String? texto1;
  String? texto2;
  final _formKey = GlobalKey<FormState>();
  final _pinPutController = TextEditingController();
  final _pinPutFocusNode = FocusNode();

  @override
  void initState() {
    texto1 = widget.titulo;
    texto2 = widget.subtitulo;
    super.initState();
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
          onTap: () => Navigator.pop(context, false),
        ),
        title: Text(
          AppLocalizations.of(context)!.translate(texto1!),
          style: TextStyle(color: gris),
        ),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(10),
              child: Text(
                AppLocalizations.of(context)!.translate(texto2!),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(50),
            child: pinputWithNumbers(),
          )
        ],
      ),
    );
  }

  Widget pinputWithNumbers() {
    final BoxDecoration pinPutDecoration = BoxDecoration(
      color: gris,
      borderRadius: BorderRadius.circular(5.0),
    );
    return Form(
      key: _formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onLongPress: () {
              print(_formKey.currentState!.validate());
            },
            onTap: () {
              _pinPutFocusNode.unfocus();
            },
            child: PinCodeTextField(
              appContext: context,
              length: 4,
              controller: _pinPutController,
              focusNode: _pinPutFocusNode,
              showCursor: true,
              cursorColor: primary,
              pinTheme: PinTheme(
                shape: PinCodeFieldShape.box,
                borderRadius: BorderRadius.circular(5.0),
                fieldHeight: 50.0,
                fieldWidth: 50.0,
                activeFillColor: Colors.transparent,
                inactiveFillColor: Colors.transparent,
                selectedFillColor: Colors.transparent,
                activeColor: gris,
                inactiveColor: gris,
                selectedColor: primary,
              ),
              enableActiveFill: false,
              onChanged: (value) {
                // Handle value changes if needed
              },
              onCompleted: (value) {
                // Handle completion if needed
              },
            ),
          ),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            padding: const EdgeInsets.all(30),
            physics: const NeverScrollableScrollPhysics(),
            children: [
              ...[1, 2, 3, 4, 5, 6, 7, 8, 9, 0].map((e) {
                return RoundedButton(
                  content: Text(
                    '$e',
                    style: TextStyle(
                      fontSize: 20,
                      color: blanco,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () {
                    if (_pinPutController.text.length >= 4) return;

                    _pinPutController.text = '${_pinPutController.text}$e';
                  },
                );
              }),
              RoundedButton(
                content: Icon(
                  Icons.backspace,
                  color: blanco,
                ),
                onTap: () {
                  if (_pinPutController.text.isNotEmpty) {
                    _pinPutController.text = _pinPutController.text
                        .substring(0, _pinPutController.text.length - 1);
                  }
                },
              ),
              RoundedButton(
                content: Icon(
                  Icons.double_arrow,
                  color: blanco,
                ),
                onTap: () {
                  if (_pinPutController.text.isNotEmpty &&
                      _pinPutController.text.length == 4) {
                    var cero = _pinPutController.text.indexOf('0');
                    if (cero != 0) {
                      Navigator.pop(context, _pinPutController.text);
                    } else {
                      mostrarAlerta(
                        context,
                        AppLocalizations.of(context)!.translate('WARNING'),
                        AppLocalizations.of(context)!
                            .translate('INVALID_NUMBER'),
                      );
                    }
                  } else {
                    mostrarAlerta(
                      context,
                      AppLocalizations.of(context)!.translate('WARNING'),
                      AppLocalizations.of(context)!.translate('INVALID_CODE'),
                    );
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class RoundedButton extends StatelessWidget {
  final Widget content;
  final VoidCallback onTap;

  const RoundedButton({super.key, required this.content, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(5),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: gris,
        ),
        alignment: Alignment.center,
        child: content,
        // child: Text(
        //   '$title',
        //   style: TextStyle(
        //     fontSize: 20,
        //     color: blanco,
        //   ),
        // ),
      ),
    );
  }
}
