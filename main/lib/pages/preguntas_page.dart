import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:CryptoChat/global/AppLocalizations.dart';
import 'package:CryptoChat/helpers/style.dart';
import 'package:CryptoChat/services/auth_service.dart';
import 'package:CryptoChat/services/socket_service.dart';
import 'package:CryptoChat/services/usuarios_service.dart';
import 'package:CryptoChat/widgets/toast_message.dart';

class PreguntasPage extends StatefulWidget {
  const PreguntasPage({super.key});

  @override
  _PreguntasPageState createState() => _PreguntasPageState();
}

class _PreguntasPageState extends State<PreguntasPage> {
  String dropdownValue1 = 'SELECT_QUESTION';
  String dropdownValue2 = 'SELECT_QUESTION';
  String dropdownValue3 = 'SELECT_QUESTION';
  final _textController1 = TextEditingController();
  final _textController2 = TextEditingController();
  final _textController3 = TextEditingController();
  final _textController4 = TextEditingController();
  final _textControllerP = TextEditingController();
  List<String> preguntas1 = [
    "SELECT_QUESTION",
    "QUESTION_1",
    "QUESTION_2",
    "QUESTION_3",
    "QUESTION_4",
    "QUESTION_5",
  ];
  List<String> preguntas2 = [
    "SELECT_QUESTION",
    "QUESTION_6",
    "QUESTION_7",
    "QUESTION_8",
    "QUESTION_9",
    "QUESTION_10",
  ];
  List<String> preguntas3 = [
    "SELECT_QUESTION",
    "QUESTION_11",
    "QUESTION_12",
    "QUESTION_13",
    "QUESTION_14",
    "QUESTION_15",
  ];

  AuthService? authService;
  SocketService? socketService;
  final usuarioService = UsuariosService();

  @override
  void initState() {
    authService = Provider.of<AuthService>(context, listen: false);
    socketService = Provider.of<SocketService>(context, listen: false);
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
          onTap: () => Navigator.pop(context),
        ),
        title: Text(
          AppLocalizations.of(context)!.translate('SECURITY_QUESTIONS'),
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
              value: dropdownValue1,
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              iconSize: 24,
              elevation: 16,
              dropdownColor: chat_color,
              style: TextStyle(
                color: gris,
              ),
              onChanged: (value) {
                setState(() {
                  dropdownValue1 = value!;
                });
              },
              items: preguntas1.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(AppLocalizations.of(context)!.translate(value)),
                );
              }).toList(),
            ),
          ),
          Container(
            padding: const EdgeInsets.only(top: 5, bottom: 5, left: 10),
            margin: const EdgeInsets.only(bottom: 10, left: 50, right: 50),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: gris),
            ),
            child: TextField(
              controller: _textController1,
              decoration: InputDecoration(
                labelText:
                    '${AppLocalizations.of(context)!.translate('ANSWER')} 1',
                labelStyle: TextStyle(
                  fontWeight: FontWeight.normal,
                  color: gris,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
          const Divider(
            indent: 20,
            endIndent: 20,
          ),
          Container(
            margin: const EdgeInsets.only(left: 50, right: 50),
            child: DropdownButton<String>(
              isExpanded: true,
              value: dropdownValue2,
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              iconSize: 24,
              elevation: 16,
              dropdownColor: chat_color,
              style: TextStyle(
                color: gris,
              ),
              onChanged: (value) {
                setState(() {
                  dropdownValue2 = value!;
                });
              },
              items: preguntas2.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(AppLocalizations.of(context)!.translate(value)),
                );
              }).toList(),
            ),
          ),
          Container(
            padding: const EdgeInsets.only(top: 5, bottom: 5, left: 10),
            margin: const EdgeInsets.only(bottom: 10, left: 50, right: 50),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: gris),
            ),
            child: TextField(
              controller: _textController2,
              decoration: InputDecoration(
                labelText:
                    '${AppLocalizations.of(context)!.translate('ANSWER')} 2',
                labelStyle: TextStyle(
                  fontWeight: FontWeight.normal,
                  color: gris,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
          const Divider(
            indent: 20,
            endIndent: 20,
          ),
          Container(
            margin: const EdgeInsets.only(left: 50, right: 50),
            child: DropdownButton<String>(
              isExpanded: true,
              value: dropdownValue3,
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              iconSize: 24,
              elevation: 16,
              dropdownColor: chat_color,
              style: TextStyle(
                color: gris,
              ),
              onChanged: (value) {
                setState(() {
                  dropdownValue3 = value!;
                });
              },
              items: preguntas3.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(AppLocalizations.of(context)!.translate(value)),
                );
              }).toList(),
            ),
          ),
          Container(
            padding: const EdgeInsets.only(top: 5, bottom: 5, left: 10),
            margin: const EdgeInsets.only(bottom: 10, left: 50, right: 50),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: gris),
            ),
            child: TextField(
              controller: _textController3,
              decoration: InputDecoration(
                labelText:
                    '${AppLocalizations.of(context)!.translate('ANSWER')} 3',
                labelStyle: TextStyle(
                  fontWeight: FontWeight.normal,
                  color: gris,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
          const Divider(
            indent: 20,
            endIndent: 20,
          ),
          Container(
            padding: const EdgeInsets.only(top: 5, bottom: 5, left: 10),
            margin: const EdgeInsets.only(bottom: 10, left: 50, right: 50),
            child: TextField(
              controller: _textControllerP,
              decoration: InputDecoration(
                labelText:
                    AppLocalizations.of(context)!.translate('CREATE_QUESTION'),
                labelStyle: TextStyle(
                  fontWeight: FontWeight.normal,
                  color: gris,
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.only(top: 5, bottom: 5, left: 10),
            margin: const EdgeInsets.only(bottom: 10, left: 50, right: 50),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: gris),
            ),
            child: TextField(
              controller: _textController4,
              decoration: InputDecoration(
                labelText:
                    '${AppLocalizations.of(context)!.translate('ANSWER')} 4',
                labelStyle: TextStyle(
                  fontWeight: FontWeight.normal,
                  color: gris,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
          const Divider(
            indent: 20,
            endIndent: 20,
          ),
          Container(
            margin: const EdgeInsets.only(left: 100, right: 100, bottom: 30, top: 30),
            child: SizedBox.fromSize(
              size: Size(MediaQuery.of(context).size.width * 0.5, 50),
              child: Material(
                borderRadius: BorderRadius.circular(15),
                color: primary,
                child: InkWell(
                  borderRadius: BorderRadius.circular(15),
                  splashColor: secondary,
                  child: Center(
                    child: Text(
                      AppLocalizations.of(context)!.translate('SAVE'),
                      style: TextStyle(color: drawer_white),
                    ),
                  ),
                  onTap: () {
                    // Validate questions are selected
                    if (dropdownValue1 == 'SELECT_QUESTION' ||
                        dropdownValue2 == 'SELECT_QUESTION' ||
                        dropdownValue3 == 'SELECT_QUESTION') {
                      showToast(
                          context,
                          AppLocalizations.of(context)!
                              .translate('SELECT_QUESTION'),
                          rojo.withOpacity(0.8),
                          Icons.cancel_outlined);
                      return;
                    }

                    // Validate answers are provided
                    if (_textController1.text.trim().isEmpty ||
                        _textController2.text.trim().isEmpty ||
                        _textController3.text.trim().isEmpty ||
                        _textController4.text.trim().isEmpty) {
                      showToast(
                          context,
                          AppLocalizations.of(context)!
                              .translate('MSG_EMPTY_FIELDS'),
                          rojo.withOpacity(0.8),
                          Icons.cancel_outlined);
                      return;
                    }

                    List preguntas = [
                      AppLocalizations.of(context)!.translate(dropdownValue1),
                      AppLocalizations.of(context)!.translate(dropdownValue2),
                      AppLocalizations.of(context)!.translate(dropdownValue3),
                      _textControllerP.text.trim()
                    ];
                    List respuestas = [
                      _textController1.text.trim(),
                      _textController2.text.trim(),
                      _textController3.text.trim(),
                      _textController4.text.trim()
                    ];

                    // Try to save - HTTP works independently of Socket.IO
                    usuarioService
                        .guardarPreguntas(
                            preguntas, respuestas, authService!.usuario!.uid)
                        .then((res) {
                      if (res == "MSG102") {
                        usuarioService
                            .infoUserChange(
                                'false', 'new', authService!.usuario!.uid)
                            .then((value) {
                          authService!.usuario!.nuevo = 'false';
                          // Mark security questions as completed
                          SharedPreferences.getInstance().then((prefs) {
                            prefs.setBool('hasSkippedOrCompletedSecurityQuestions', true);
                          });
                        });
                        showToast(
                            context,
                            AppLocalizations.of(context)!.translate('MSG102'),
                            primary.withOpacity(0.8),
                            Icons.check_circle_outline);
                        Navigator.pop(context);
                      } else {
                        print('Error saving questions: $res');
                        showToast(
                            context,
                            AppLocalizations.of(context)!.translate('ERR102'),
                            rojo.withOpacity(0.8),
                            Icons.cancel_outlined);
                      }
                    }).catchError((error) {
                      print('Error in guardarPreguntas: $error');
                      showToast(
                          context,
                          AppLocalizations.of(context)!
                              .translate('NO_CONECTION'),
                          rojo.withOpacity(0.8),
                          Icons.cancel_outlined);
                    });
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
