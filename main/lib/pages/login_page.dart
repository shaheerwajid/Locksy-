import 'package:flutter/material.dart';
import 'package:CryptoChat/global/AppLanguage.dart';
import 'package:CryptoChat/global/AppLocalizations.dart';
import 'package:CryptoChat/global/environment.dart';
import 'package:CryptoChat/helpers/funciones.dart';
import 'package:CryptoChat/helpers/style.dart';
import 'package:CryptoChat/services/auth_service.dart';
import 'package:CryptoChat/services/socket_service.dart';
import 'package:CryptoChat/widgets/mostrar_alerta.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final textController = TextEditingController();
  AppLanguage? langService;

  @override
  void initState() {
    langService = Provider.of<AppLanguage>(context, listen: false);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.center,
            colors: [
              background,
              background,
            ],
          ),
        ),
        child: SafeArea(
          child: ListView(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Row(
                  //   mainAxisAlignment: MainAxisAlignment.end,
                  //   children: [
                  //     Container(
                  //       margin: EdgeInsets.only(left: 20, top: 20),
                  //       child: FloatingActionButton(
                  //         mini: true,
                  //         onPressed: share,
                  //         child: Icon(
                  //           Icons.share_rounded,
                  //           color: icon_color,
                  //           size: 25,
                  //         ),
                  //         backgroundColor: primary,
                  //         heroTag: 'btn-share',
                  //       ),
                  //     ),
                  //     Container(
                  //       margin: EdgeInsets.only(right: 0, top: 20),
                  //       child: FloatingActionButton(
                  //         mini: true,
                  //         //onPressed: cambiarIdioma,
                  //         onPressed: () =>
                  //             Navigator.pushNamed(context, 'idiomas'),
                  //         child: Icon(
                  //           Icons.language,
                  //           color: icon_color,
                  //           size: 25,
                  //         ),
                  //         backgroundColor: primary,
                  //       ),
                  //     ),
                  //     Container(
                  //       margin: EdgeInsets.only(right: 20, top: 20),
                  //       child: FloatingActionButton(
                  //         mini: true,
                  //         onPressed: () {
                  //           // Call the "about" onTap function here
                  //           lauchURL(Environment.urlTerminos); // This will launch the URL for the Terms
                  //         },
                  //         child: Icon(
                  //           Icons.note_alt_rounded,
                  //           color: icon_color,
                  //           size: 25,
                  //         ),
                  //         backgroundColor: primary,
                  //       ),
                  //     ),
                  //   ],
                  // ),
                  const SizedBox(height: 100),
                  const Image(
                    image: AssetImage('assets/banner/icon_img.png'),
                    width: 250.0,
                  ),
                  const SizedBox(height: 30),
                  // Image(
                  //   image: AssetImage('assets/banner/text_img.png'),
                  //   width: 140.0,
                  // ),
                  //SizedBox(height: 70),
                  _Form(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future lauchURL(String url) async {
    if (await canLaunch(url)) {
      await launch(
        url,
        forceSafariVC: false,
        forceWebView: false,
        enableJavaScript: true,
      ); //
    } else {
      // print('Could not launch $url');
    }
  }

  Future<void> share() async {
    await Share.share(AppLocalizations.of(context)!.translate('SHARE_TEXT'),
        subject: Environment.urlWebPage);
  }

  /* cambiarIdioma() async {
    var prefs = await SharedPreferences.getInstance();
    Locale idiomaActual = Locale(prefs.getString('language_code'));
    langService
        .changeLanguage2(idiomaActual.languageCode == "es" ? "en" : "es");
    // Phoenix.rebirth(context);
  } */
}

class _Form extends StatefulWidget {
  @override
  __FormState createState() => __FormState();
}

class __FormState extends State<_Form> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final socketService = Provider.of<SocketService>(context);
    bool loginOk = false;
    return Container(
      padding: const EdgeInsets.only(left: 20, top: 40, right: 20, bottom: 20),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 22), // Adjust as needed
            margin: const EdgeInsets.symmetric(horizontal: 22),
            decoration: BoxDecoration(
              color: blanco.withOpacity(0.8),
              borderRadius: BorderRadius.circular(10),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: negro.withOpacity(0.2),
                  offset: const Offset(0, 2),
                  blurRadius: 5,
                )
              ],
            ),
            child: TextField(
              controller: emailCtrl,
              textInputAction: TextInputAction.next,
              style: TextStyle(
                fontFamily: 'roboto-regular',
                letterSpacing: 1.0,
                color: text_color,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
              autocorrect: false,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(
                      right: 18), // Adjust this value to move the icon
                  child: Icon(Icons.mail_rounded, color: primary),
                ),
                labelText: AppLocalizations.of(context)!.translate('EMAIL'),
                labelStyle: TextStyle(
                  fontFamily: 'roboto-regular',
                  letterSpacing: 1.0,
                  fontWeight: FontWeight.normal,
                  color: gris.withOpacity(0.8),
                  fontSize: 20,
                ),
                focusedBorder: InputBorder.none,
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 22), // Adjust as needed
            margin: const EdgeInsets.symmetric(horizontal: 22),
            decoration: BoxDecoration(
              color: blanco.withOpacity(0.8),
              borderRadius: BorderRadius.circular(10),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: negro.withOpacity(0.2),
                  offset: const Offset(0, 2),
                  blurRadius: 5,
                )
              ],
            ),
            child: TextField(
              controller: passCtrl,
              style: TextStyle(
                fontFamily: 'roboto-regular',
                letterSpacing: 1.0,
                color: text_color,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
              autocorrect: false,
              obscureText: true,
              decoration: InputDecoration(
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(
                      right: 18), // Adjust this value to move the icon
                  child: Icon(Icons.lock_outline_rounded, color: primary),
                ),
                labelText: AppLocalizations.of(context)!.translate('PASSWORD'),
                labelStyle: TextStyle(
                  fontFamily: 'roboto-regular',
                  letterSpacing: 1.0,
                  fontWeight: FontWeight.normal,
                  color: gris.withOpacity(0.8),
                  fontSize: 20,
                ),
                focusedBorder: InputBorder.none,
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 40),
          // ElevatedButton(
          //   style: ButtonStyle(
          //     backgroundColor: MaterialStateProperty.all(primary),
          //     elevation: MaterialStateProperty.all(2),
          //     shape: MaterialStateProperty.all(
          //       RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          //     ),
          //   ),
          //   child: Container(
          //     width: 240,
          //     height: 50,
          //     child: Center(
          //       child: Text(
          //         AppLocalizations.of(context)!.translate('ENTER'),
          //         style: TextStyle(
          //           color: white,
          //           fontSize: 25,
          //           fontWeight: FontWeight.bold,
          //         ),
          //       ),
          //     ),
          //   ),
          //   onPressed: authService.autenticando
          //       ? null
          //       : () async {
          //           FocusScope.of(context).unfocus();
          //           if (emailCtrl.text != "" && passCtrl.text != "") {
          //             if (validateEmail(emailCtrl.text)) {
          //               loginOk = await authService.login(
          //                 emailCtrl.text.trim(),
          //                 passCtrl.text.trim(),
          //               );
          //
          //               if (loginOk) {
          //                 // print(
          //                 //     "connecting .........${socketService.check()}.......${socketService.serverStatus}........");
          //
          //                 socketService.connect();
          //                 socketService.getKeys();
          //                 Navigator.pushReplacementNamed(context, 'home');
          //               } else {
          //                 // Mostara alerta
          //                 mostrarAlerta(
          //                   context,
          //                   AppLocalizations.of(context)!
          //                       .translate('INCORRECT_LOGIN'),
          //                   AppLocalizations.of(context)!
          //                       .translate('MSG_CHECK_CREDENTIALS'),
          //                 );
          //               }
          //             } else {
          //               mostrarAlerta(
          //                   context,
          //                   AppLocalizations.of(context)!.translate('ERROR'),
          //                   AppLocalizations.of(context)!
          //                       .translate('MSG_INVALID_EMAIL'));
          //             }
          //           } else {
          //             mostrarAlerta(
          //                 context,
          //                 AppLocalizations.of(context)!.translate('ERROR'),
          //                 AppLocalizations.of(context)!
          //                     .translate('MSG_ENTER_CREDENTIALS'));
          //           }
          //         },
          // ),

          Semantics(
            label: AppLocalizations.of(context)!.translate('ENTER'),
            button: true,
            enabled: !authService.autenticando,
            child: ElevatedButton(
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all(primary),
                elevation: WidgetStateProperty.all(2),
                shape: WidgetStateProperty.all(
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              onPressed: authService.autenticando
                  ? null
                  : () async {
                    FocusScope.of(context).unfocus();
                    if (emailCtrl.text != "" && passCtrl.text != "") {
                      if (validateEmail(emailCtrl.text)) {
                        setState(() {
                          isLoading = true;
                        });

                        loginOk = await authService.login(
                          emailCtrl.text.trim(),
                          passCtrl.text.trim(),
                        );

                        setState(() {
                          isLoading = false;
                        });

                        if (loginOk) {
                          socketService.connect();
                          socketService.getKeys();
                          Navigator.pushReplacementNamed(context, 'home');
                        } else {
                          mostrarAlerta(
                            context,
                            AppLocalizations.of(context)!
                                .translate('INCORRECT_LOGIN'),
                            AppLocalizations.of(context)!
                                .translate('MSG_CHECK_CREDENTIALS'),
                          );
                        }
                      } else {
                        mostrarAlerta(
                            context,
                            AppLocalizations.of(context)!.translate('ERROR'),
                            AppLocalizations.of(context)!
                                .translate('MSG_INVALID_EMAIL'));
                      }
                    } else {
                      mostrarAlerta(
                          context,
                          AppLocalizations.of(context)!.translate('ERROR'),
                          AppLocalizations.of(context)!
                              .translate('MSG_ENTER_CREDENTIALS'));
                    }
                  },
              child: SizedBox(
                width: 240,
                height: 50,
                child: Center(
                  child: isLoading
                      ? const SizedBox(
                          width: 25.0,
                          height: 25.0,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          AppLocalizations.of(context)!.translate('ENTER'),
                          style: TextStyle(
                            fontFamily: 'roboto-medium',
                            letterSpacing: 1.0,
                            color: drawer_white,
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Semantics(
                label: AppLocalizations.of(context)!.translate('FORGOT_PASSWORD'),
                button: true,
                child: GestureDetector(
                  child: Text(
                    AppLocalizations.of(context)!.translate('FORGOT_PASSWORD'),
                    style: TextStyle(
                      color: text_color,
                      fontFamily: 'roboto-medium',
                      fontSize: 15,
                      //decoration: TextDecoration.underline,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () {
                    Navigator.pushNamed(context, 'recovery');
                  },
                ),
              )
            ],
          ),
          const SizedBox(height: 5),

          // Signup/Register button
          Container(
            child: Column(
              children: <Widget>[
                Semantics(
                  label: AppLocalizations.of(context)!.translate('CREATE_ACCOUNT'),
                  button: true,
                  child: GestureDetector(
                    child: Text(
                      AppLocalizations.of(context)!.translate('CREATE_ACCOUNT'),
                      style: TextStyle(
                        color: gris,
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    onTap: () {
                      Navigator.pushNamed(context, 'register');
                    },
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 1),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    margin: const EdgeInsets.only(left: 20, top: 20),
                    child: Semantics(
                      label: AppLocalizations.of(context)!.translate('TERMS_AND_CONDITIONS') ?? 'View Terms and Conditions',
                      button: true,
                      child: FloatingActionButton(
                        mini: true,
                        heroTag: 'login-terms',
                        onPressed: () {
                          // Call the "about" onTap function here
                          lauchURL(Environment
                              .urlTerminos); // This will launch the URL for the Terms
                        },
                        backgroundColor: primary,
                        child: Icon(
                          Icons.note_alt_rounded,
                          color: icon_color,
                          size: 25,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(right: 0, top: 20),
                    child: Semantics(
                      label: AppLocalizations.of(context)!.translate('LANGUAGE') ?? 'Change Language',
                      button: true,
                      child: FloatingActionButton(
                        mini: true,
                        heroTag: 'login-language',
                        //onPressed: cambiarIdioma,
                        onPressed: () => Navigator.pushNamed(context, 'idiomas'),
                        backgroundColor: primary,
                        child: Icon(
                          Icons.language,
                          color: icon_color,
                          size: 25,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(right: 20, top: 20),
                    child: Semantics(
                      label: AppLocalizations.of(context)!.translate('SHARE') ?? 'Share App',
                      button: true,
                      child: FloatingActionButton(
                        mini: true,
                        onPressed: share,
                        backgroundColor: primary,
                        heroTag: 'btn-share',
                        child: Icon(
                          Icons.share_rounded,
                          color: icon_color,
                          size: 25,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Row(
          //   mainAxisAlignment: MainAxisAlignment.center,
          //   children: [
          //     Icon(
          //       Icons.copyright_outlined,
          //       color: text_color,
          //       size: 15,
          //     ),
          //     Text(
          //       "$year Locksy.",
          //       style: TextStyle(
          //         color: primary,
          //         fontFamily: 'roboto-black',
          //         letterSpacing: 1.0,
          //         fontSize: 13,
          //         fontWeight: FontWeight.bold,
          //       ),
          //     ),
          //   ],
          // ),

          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(
                  bottom: 20), // Adjust the padding to move it up/down
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "CopyRights",
                    style: TextStyle(
                      color: text_color,
                      fontFamily: 'roboto-black',
                      letterSpacing: 1.0,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(
                    Icons.copyright_outlined,
                    color: text_color,
                    size: 15,
                  ),
                  const SizedBox(width: 5),
                  Image.asset(
                    'assets/banner/icon_img.png',
                    width: 60, // Set the desired width for the image
                    height: 50, // Set the desired height for the image
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Future<void> share() async {
    await Share.share(AppLocalizations.of(context)!.translate('SHARE_TEXT'),
        subject: Environment.urlWebPage);
  }

  Future lauchURL(String url) async {
    if (await canLaunch(url)) {
      await launch(
        url,
        forceSafariVC: false,
        forceWebView: false,
        enableJavaScript: true,
      ); //
    } else {
      // print('Could not launch $url');
    }
  }
}
