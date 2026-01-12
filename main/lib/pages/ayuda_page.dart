import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:CryptoChat/global/AppLocalizations.dart';
import 'package:CryptoChat/global/environment.dart';
import 'package:CryptoChat/helpers/style.dart';
import 'package:CryptoChat/models/usuario.dart';
import 'package:CryptoChat/services/auth_service.dart';
import 'package:CryptoChat/services/usuarios_service.dart';
import 'package:url_launcher/url_launcher.dart';

class AyudaPage extends StatefulWidget {
  const AyudaPage({super.key});

  @override
  _AyudaPageState createState() => _AyudaPageState();
}

class _AyudaPageState extends State<AyudaPage> {
  String dropdownValue = 'SELECT_OPTION';
  final _textController = TextEditingController();

  List<String> opciones = [
    "SELECT_OPTION",
    "OPTION_1",
    "OPTION_2",
    "OPTION_3",
    "OPTION_4",
    "OPTION_5",
  ];

  AuthService? authService;
  Usuario? usuario;

  @override
  void initState() {
    authService = Provider.of<AuthService>(context, listen: false);
    usuario = authService!.usuario;
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
          onTap: () => Navigator.pop(context, true),
        ),
        title: Text(
          AppLocalizations.of(context)!.translate('HELP'),
          style: TextStyle(color: gris),
        ),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          Container(
            margin: const EdgeInsets.only(left: 50, right: 50),
            child: DropdownButton<String>(
              isExpanded: true,
              value: dropdownValue,
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              iconSize: 24,
              elevation: 16,
              dropdownColor: chat_color,
              style: TextStyle(
                color: negro.withOpacity(0.8),
              ),
              onChanged: (value) {
                setState(() {
                  dropdownValue = value!;
                });
              },
              items: opciones.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(AppLocalizations.of(context)!.translate(value)),
                );
              }).toList(),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(left: 50, top: 40),
            child: Text(
              AppLocalizations.of(context)!.translate('DESCRIPTION'),
              style: TextStyle(color: negro.withOpacity(0.8)),
            ),
          ),
          Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.only(left: 20, top: 10, bottom: 10, right: 20),
            decoration: BoxDecoration(
                border: Border.all(color: gris),
                borderRadius: BorderRadius.circular(15)),
            child: TextField(
              controller: _textController,
              minLines: 5,
              maxLines: 5,
              decoration: const InputDecoration(
                border: InputBorder.none,
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox.fromSize(
                size: Size(MediaQuery.of(context).size.width * 0.5, 50), // Adjust width here
                child: Material(
                  borderRadius: BorderRadius.circular(15),
                  color: primary,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(15),
                    splashColor: secondary,
                    child: Center(
                      child: Text(
                        AppLocalizations.of(context)!.translate('SEND'),
                        style: TextStyle(color: blanco),
                      ),
                    ),
                    onTap: () async {
                      final usuarioService = UsuariosService();
                      await usuarioService.sendSolicitud(
                        usuario!.uid,
                        dropdownValue,
                        _textController.text,
                      );

                      Navigator.pop(context);
                    },
                  ),
                ),
              ),
            ],
          ),
          Container(
            margin: const EdgeInsets.only(top: 50),
            child: GestureDetector(
              child: Text(
                AppLocalizations.of(context)!.translate('FREQUENT_QUESTIONS'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: gris,
                  fontSize: 18,
                  decoration: TextDecoration.underline,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () => lauchURL(Environment.urlFAQ),
            ),
          ),
        ],
      ),
    );
  }

  Future lauchURL(String url) async {
    try {
      await launch(
        url,
        forceSafariVC: false,
        forceWebView: false,
        enableJavaScript: true,
      );
    } catch (e) {
      // print('Could not launch $url');
    }
  }
}
