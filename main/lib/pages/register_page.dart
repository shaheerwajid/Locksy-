import 'package:flutter/material.dart';
import 'package:CryptoChat/global/AppLocalizations.dart';
import 'package:CryptoChat/helpers/funciones.dart';
import 'package:CryptoChat/helpers/style.dart';
import 'package:CryptoChat/widgets/mostrar_alerta.dart';
import 'package:provider/provider.dart';
import 'package:provider/provider.dart';

import 'package:CryptoChat/services/auth_service.dart';
import 'package:CryptoChat/services/socket_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final textController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                gris,
                gris,
              ]),
        ),
        child: SafeArea(
          child: ListView(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(right: 20, top: 20, left: 20),
                        child: FloatingActionButton(
                          mini: true,
                          heroTag: 'register-back',
                          onPressed: () {
                            Navigator.pop(context);
                            FocusScope.of(context).unfocus();
                          },
                          backgroundColor: blanco.withOpacity(0.8),
                          child: Icon(
                            Icons.arrow_back_ios_rounded,
                            color: gris.withOpacity(0.8),
                            size: 30,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Image(
                    image: AssetImage('assets/banner/icon_img.png'),
                    width: 130.0,
                  ),
                  const SizedBox(height: 30),
                  const Image(
                    image: AssetImage('assets/banner/text_img.png'),
                    width: 140.0,
                  ),
                  const SizedBox(height: 70),
                  _Form(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Form extends StatefulWidget {
  @override
  __FormState createState() => __FormState();
}

class __FormState extends State<_Form> {
  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final pass2Ctrl = TextEditingController();
  final referCode = TextEditingController();
  bool _checked = false;
  
  // Single form key for the whole page
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    nameCtrl.dispose();
    emailCtrl.dispose();
    passCtrl.dispose();
    pass2Ctrl.dispose();
    referCode.dispose();
    super.dispose();
  }

  bool _isValid() {
    return nameCtrl.text.trim().isNotEmpty &&
        emailCtrl.text.trim().isNotEmpty &&
        validateEmail(emailCtrl.text.trim()) &&
        passCtrl.text.trim().isNotEmpty &&
        pass2Ctrl.text.trim().isNotEmpty &&
        passCtrl.text == pass2Ctrl.text &&
        _checked;
  }

  String _getErrorMessage(String? errorCode) {
    switch (errorCode) {
      case 'ERR101':
        return 'Email already exists. Please use a different email.';
      case 'ERR102':
      default:
        return 'An error occurred. Please try again later.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = DateTime.now();
    var year = date.year;
    final authService = Provider.of<AuthService>(context);
    final socketService = Provider.of<SocketService>(context);
    var registroOk;

    return Container(
      padding: const EdgeInsets.only(left: 20, top: 40, right: 20, bottom: 20),
      alignment: Alignment.center,
      decoration: BoxDecoration(
          color: blanco,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(40),
            topRight: Radius.circular(40),
          )),
      child: Column(
        children: <Widget>[
          const SizedBox(height: 10),
          Form(
            key: _formKey,
            child: Column(
              children: [
                // Name Field
                Container(
                  padding: const EdgeInsets.only(right: 20),
                  margin: const EdgeInsets.only(bottom: 20, left: 40, right: 40),
                  decoration: BoxDecoration(
                    color: amarilloClaro,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: negro.withOpacity(0.2),
                        offset: const Offset(0, 2),
                        blurRadius: 5,
                      )
                    ],
                  ),
                  child: TextFormField(
                    maxLength: 15,
                    enableSuggestions: true,
                    controller: nameCtrl,
                    textInputAction: TextInputAction.next,
                    style: TextStyle(
                        color: negro.withOpacity(0.5),
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        height: 1),
                    autocorrect: false,
                    keyboardType: TextInputType.name,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return AppLocalizations.of(context)!.translate('MSG_EMPTY_FIELDS') ?? 'Name is required';
                      }
                      if (value.trim().length < 2) {
                        return 'Name must be at least 2 characters';
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.all(2),
                      prefixIcon: Icon(Icons.person, color: gris),
                      labelText: AppLocalizations.of(context)!.translate('NAME'),
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.normal,
                        color: gris.withOpacity(0.8),
                        fontSize: 20,
                      ),
                      focusedBorder: InputBorder.none,
                      border: InputBorder.none,
                      errorStyle: TextStyle(
                        color: colorError,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),

                // Email Field
                Container(
                  padding: const EdgeInsets.all(0),
                  margin: const EdgeInsets.only(bottom: 20, left: 40, right: 40),
                  decoration: BoxDecoration(
                    color: amarilloClaro,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: negro.withOpacity(0.2),
                        offset: const Offset(0, 2),
                        blurRadius: 5,
                      )
                    ],
                  ),
                  child: TextFormField(
                    controller: emailCtrl,
                    textInputAction: TextInputAction.next,
                    style: TextStyle(
                      color: negro.withOpacity(0.5),
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                    autocorrect: false,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return AppLocalizations.of(context)!.translate('MSG_EMPTY_FIELDS') ?? 'Email is required';
                      }
                      if (!validateEmail(value.trim())) {
                        return AppLocalizations.of(context)!.translate('MSG_INVALID_EMAIL') ?? 'Please enter a valid email address';
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.mail, color: gris),
                      labelText: AppLocalizations.of(context)!.translate('EMAIL'),
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.normal,
                        color: gris.withOpacity(0.8),
                        fontSize: 20,
                      ),
                      focusedBorder: InputBorder.none,
                      border: InputBorder.none,
                      errorStyle: TextStyle(
                        color: colorError,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),

                // Password Field
                Container(
                  padding: const EdgeInsets.all(0),
                  margin: const EdgeInsets.only(bottom: 20, left: 40, right: 40),
                  decoration: BoxDecoration(
                    color: blanco.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: negro.withOpacity(0.2),
                        offset: const Offset(0, 2),
                        blurRadius: 5,
                      )
                    ],
                  ),
                  child: TextFormField(
                    controller: passCtrl,
                    textInputAction: TextInputAction.next,
                    style: TextStyle(
                      color: negro.withOpacity(0.5),
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                    autocorrect: false,
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return AppLocalizations.of(context)!.translate('MSG_EMPTY_FIELDS') ?? 'Password is required';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.vpn_key_rounded, color: gris),
                      labelText: AppLocalizations.of(context)!.translate('PASSWORD'),
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.normal,
                        color: gris.withOpacity(0.8),
                        fontSize: 20,
                      ),
                      focusedBorder: InputBorder.none,
                      border: InputBorder.none,
                      errorStyle: TextStyle(
                        color: colorError,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),

                // Confirm Password Field
                Container(
                  padding: const EdgeInsets.all(0),
                  margin: const EdgeInsets.only(bottom: 20, left: 40, right: 40),
                  decoration: BoxDecoration(
                    color: blanco.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: negro.withOpacity(0.2),
                        offset: const Offset(0, 2),
                        blurRadius: 5,
                      )
                    ],
                  ),
                  child: TextFormField(
                    controller: pass2Ctrl,
                    style: TextStyle(
                      color: negro.withOpacity(0.5),
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                    autocorrect: false,
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return AppLocalizations.of(context)!.translate('MSG_EMPTY_FIELDS') ?? 'Please confirm your password';
                      }
                      if (value != passCtrl.text) {
                        return AppLocalizations.of(context)!.translate('MSG_INVALID_PASSWORD') ?? 'Passwords do not match';
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.vpn_key_rounded, color: gris),
                      labelText:
                          AppLocalizations.of(context)!.translate('REPEAT_PASSWORD'),
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.normal,
                        color: gris.withOpacity(0.8),
                        fontSize: 20,
                      ),
                      focusedBorder: InputBorder.none,
                      border: InputBorder.none,
                      errorStyle: TextStyle(
                        color: colorError,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Referral Code
          Container(
            padding: const EdgeInsets.all(0),
            margin: const EdgeInsets.only(bottom: 20, left: 40, right: 40),
            decoration: BoxDecoration(
              color: blanco.withOpacity(0.8),
              borderRadius: BorderRadius.circular(30),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: negro.withOpacity(0.2),
                  offset: const Offset(0, 2),
                  blurRadius: 5,
                )
              ],
            ),
            child: TextField(
              textCapitalization: TextCapitalization.characters,
              controller: referCode,
              style: TextStyle(
                color: negro.withOpacity(0.5),
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
              autocorrect: false,
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.local_attraction_outlined, color: gris),
                labelText:
                    AppLocalizations.of(context)!.translate('PROMOTIONAL_CODE'),
                labelStyle: TextStyle(
                  fontWeight: FontWeight.normal,
                  color: gris.withOpacity(0.8),
                  fontSize: 20,
                ),
                hintText: AppLocalizations.of(context)!.translate('OPTIONAL'),
                hintStyle: TextStyle(
                  fontSize: 10,
                  color: rojo,
                ),
                focusedBorder: InputBorder.none,
                border: InputBorder.none,
              ),
            ),
          ),

          // Terms Checkbox
          Container(
            margin: const EdgeInsets.only(left: 30),
            child: CheckboxListTile(
              title: Text(
                AppLocalizations.of(context)!.translate('ACCEPT_TERMS'),
                style: TextStyle(
                  color: gris,
                  fontSize: 12,
                ),
              ),
              controlAffinity: ListTileControlAffinity.leading,
              value: _checked,
              onChanged: (newValue) {
                setState(() {
                  _checked = newValue!;
                });
              },
            ),
          ),

          // Register Button
          ElevatedButton(
            style: ButtonStyle(
                elevation: WidgetStateProperty.all(10),
                backgroundColor: WidgetStateProperty.all(
                  _isValid() && !authService.autenticando
                      ? primary
                      : gris.withOpacity(0.8),
                ),
                shape: WidgetStateProperty.all(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                )),
            onPressed: (_isValid() && !authService.autenticando)
                ? () async {
                    if (!_formKey.currentState!.validate()) {
                      return;
                    }
                    
                    if (!_checked) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(AppLocalizations.of(context)!
                              .translate('MSG_ACCEPT_TERMS')),
                          backgroundColor: colorError,
                          duration: const Duration(seconds: 3),
                        ),
                      );
                      return;
                    }

                    registroOk = await authService.register(
                      nameCtrl.text.trim(),
                      emailCtrl.text.trim(),
                      passCtrl.text.trim(),
                      referCode.text.trim(),
                    );
                    if (registroOk == true) {
                      socketService.connect();
                      socketService.getKeys();
                      Navigator.pushNamedAndRemoveUntil(
                          context, 'home', (route) => false);
                    } else {
                      print(
                          '[REGISTER PAGE] Registration failed: $registroOk');
                      String errorMsg = _getErrorMessage(registroOk);
                      mostrarAlerta(
                        context,
                        AppLocalizations.of(context)!.translate('ERROR'),
                        errorMsg,
                      );
                    }
                  }
                : null,
            child: SizedBox(
              width: 240,
              height: 50,
              child: Center(
                child: authService.autenticando
                    ? CircularProgressIndicator(color: blanco)
                    : Text(
                        AppLocalizations.of(context)!.translate('REGISTER'),
                        style: TextStyle(
                          color: blanco,
                          fontSize: 25,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ),

          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.copyright_outlined,
                color: gris.withOpacity(0.6),
                size: 12,
              ),
              Text(
                "$year CryptoChat.",
                style: TextStyle(
                  color: gris.withOpacity(0.6),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

