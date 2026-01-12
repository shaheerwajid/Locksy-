import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:CryptoChat/global/AppLanguage.dart';
import 'package:CryptoChat/global/AppLocalizations.dart';
import 'package:CryptoChat/helpers/style.dart';
import 'package:CryptoChat/services/auth_service.dart';
import 'package:CryptoChat/widgets/mostrar_alerta.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../global/environment.dart';

class IdiomaPage extends StatefulWidget {
  const IdiomaPage({super.key});

  @override
  _IdiomaPageState createState() => _IdiomaPageState();
}

class _IdiomaPageState extends State<IdiomaPage> {
  String? selectedLanguage;
  AppLanguage? langService;
  AuthService? authService;

  @override
  void initState() {
    super.initState();
    langService = Provider.of<AppLanguage>(context, listen: false);
    authService = Provider.of<AuthService>(context, listen: false);
    _initSelectedLanguage();
  }

  Future<void> _initSelectedLanguage() async {
    var prefs = await SharedPreferences.getInstance();
    selectedLanguage = prefs.getString('language_code');
    setState(() {}); // Notify the UI to rebuild
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
          AppLocalizations.of(context)!.translate('CHOSE_LANGUAGE'),
          style: TextStyle(color: gris),
        ),
        centerTitle: true,
      ),
      body: ListView.builder(
        itemCount: Environment.idiomas.length,
        itemBuilder: (context, index) => _buildLanguageOption(
          index,
          Environment.idiomas[index],
          Environment.locales[index],
        ),
      ),
    );
  }

  Widget _buildLanguageOption(int index, String language, String locale) {
    return Column(
      children: [
        ListTile(
          tileColor: chat_color,
          leading: Image.asset(
            'assets/flags/$locale.png', // Path to the flag image (e.g., en.png, es.png)
            width: 30,
            height: 30,
          ),
          title: Text(
            language,
            style: const TextStyle(color: Color(0xff2d2d2d), fontSize: 15),
          ),
          dense: true,
          trailing: Radio<String>(
            value: locale,
            groupValue: selectedLanguage,
            activeColor: primary,
            onChanged: (value) async {
              bool confirm = await alertaConfirmar(
                context,
                AppLocalizations.of(context)!.translate('INFORMATION'),
                AppLocalizations.of(context)!.translate('ALERT_LANGUAGE'),
              );
              if (confirm) {
                final appLanguage =
                    Provider.of<AppLanguage>(context, listen: false);
                if (authService!.usuario != null) {
                  usuarioService.infoUserChange(
                    locale,
                    'idioma',
                    authService!.usuario!.uid,
                  );
                }
                await appLanguage.changeLanguage(value!); // Change the language
                setState(() {
                  selectedLanguage = value;
                });
              }
            },
          ),
        ),
        Divider(
          color: drawer_white,
          thickness: 3,
          height: 0,
        ),
      ],
    );
  }
}
