import 'package:flutter/material.dart';
import 'package:CryptoChat/global/AppLocalizations.dart';
import 'package:CryptoChat/global/environment.dart';
import 'package:CryptoChat/helpers/funciones.dart';
import 'package:CryptoChat/helpers/style.dart';
import 'package:CryptoChat/services/auth_service.dart';
import 'package:CryptoChat/widgets/mostrar_alerta.dart';
import 'package:provider/provider.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:url_launcher/url_launcher.dart';

class RecoveryPage extends StatefulWidget {
  const RecoveryPage({super.key});

  @override
  _RecoveryPageState createState() => _RecoveryPageState();
}

class _RecoveryPageState extends State<RecoveryPage> {
  final textController = TextEditingController();

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
              ]),
        ),
        child: SafeArea(
          child: ListView(
            children: <Widget>[
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(right: 20, top: 20, left: 20),
                          child: FloatingActionButton(
                            mini: true,
                            heroTag: 'recovery-back',
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            backgroundColor: primary,
                            child: Icon(
                              Icons.arrow_back_ios_rounded,
                              color: icon_color,
                              size: 30,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Image(
                      image: AssetImage('assets/banner/icon_img.png'),
                      width: 250.0,
                    ),
                    const SizedBox(height: 20),
                    _Form(),
                  ],
                ),
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
  int _currentStep = 1; // 1: Email, 2: OTP, 3: New Password
  final emailCtrl = TextEditingController();
  final otpCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final pass2Ctrl = TextEditingController();
  bool _checked = false;
  bool _sendingOTP = false;
  bool _verifyingOTP = false;
  bool _resettingPassword = false;
  String? _otpError;

  @override
  void dispose() {
    emailCtrl.dispose();
    otpCtrl.dispose();
    passCtrl.dispose();
    pass2Ctrl.dispose();
    super.dispose();
  }

  bool _isStep1Valid() {
    return emailCtrl.text.trim().isNotEmpty &&
        validateEmail(emailCtrl.text.trim());
  }

  bool _isStep2Valid() {
    return otpCtrl.text.length == 6;
  }

  bool _isStep3Valid() {
    return passCtrl.text.trim().isNotEmpty &&
        pass2Ctrl.text.trim().isNotEmpty &&
        passCtrl.text == pass2Ctrl.text &&
        _checked;
  }

  String _getErrorMessage(String? errorCode) {
    switch (errorCode) {
      case 'ERR103':
        return 'Email not found. Please check your email address.';
      case 'ERR105':
        return 'OTP expired. Please request a new OTP.';
      case 'ERR106':
        return 'Too many attempts. Please request a new OTP.';
      case 'ERR107':
        return 'Invalid OTP code. Please try again.';
      case 'ERR109':
        return 'No reset OTP requested. Please request a new OTP.';
      case 'ERR102':
      default:
        return 'An error occurred. Please try again later.';
    }
  }

  Future<void> _sendResetOTP() async {
    if (!_isStep1Valid()) {
      mostrarAlerta(
        context,
        AppLocalizations.of(context)!.translate('ERROR'),
        AppLocalizations.of(context)!.translate('MSG_ALERT_EMAIL'),
      );
      return;
    }

    if (!_checked) {
      mostrarAlerta(
        context,
        AppLocalizations.of(context)!.translate('ERROR'),
        AppLocalizations.of(context)!.translate('MSG_ACCEPT_TERMS'),
      );
      return;
    }

    setState(() {
      _sendingOTP = true;
      _otpError = null;
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    final result = await authService.forgotPassword(emailCtrl.text.trim());

    setState(() {
      _sendingOTP = false;
    });

    if (result['success'] == true) {
      setState(() {
        _currentStep = 2;
      });
      mostrarAlerta(
        context,
        AppLocalizations.of(context)!.translate('PASSWORD_CHANGE'),
        'If the email exists, an OTP has been sent to ${emailCtrl.text.trim()}. Please check your email.',
      );
    } else {
      String errorMsg = _getErrorMessage(result['msg']);
      mostrarAlerta(
        context,
        AppLocalizations.of(context)!.translate('ERROR'),
        errorMsg,
      );
    }
  }

  Future<void> _verifyResetOTP() async {
    if (!_isStep2Valid()) {
      mostrarAlerta(
        context,
        AppLocalizations.of(context)!.translate('ERROR'),
        'Please enter a valid 6-digit OTP code',
      );
      return;
    }

    setState(() {
      _verifyingOTP = true;
      _otpError = null;
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    final result = await authService.verifyResetOTP(
      emailCtrl.text.trim(),
      otpCtrl.text.trim(),
    );

    setState(() {
      _verifyingOTP = false;
    });

    if (result['success'] == true) {
      setState(() {
        _currentStep = 3;
      });
    } else {
      String errorMsg = _getErrorMessage(result['msg']);
      setState(() {
        _otpError = errorMsg;
      });
      mostrarAlerta(
        context,
        AppLocalizations.of(context)!.translate('ERROR'),
        errorMsg,
      );
    }
  }

  Future<void> _resetPassword() async {
    if (!_isStep3Valid()) {
      if (passCtrl.text != pass2Ctrl.text) {
        mostrarAlerta(
          context,
          AppLocalizations.of(context)!.translate('ERROR'),
          AppLocalizations.of(context)!.translate('MSG_INVALID_PASSWORD'),
        );
      } else if (!_checked) {
        mostrarAlerta(
          context,
          AppLocalizations.of(context)!.translate('ERROR'),
          AppLocalizations.of(context)!.translate('MSG_ACCEPT_TERMS'),
        );
      }
      return;
    }

    setState(() {
      _resettingPassword = true;
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    final result = await authService.resetPassword(
      emailCtrl.text.trim(),
      passCtrl.text.trim(),
      otpCtrl.text.trim(),
    );

    setState(() {
      _resettingPassword = false;
    });

    if (result['success'] == true) {
      mostrarAlerta(
        context,
        AppLocalizations.of(context)!.translate('PASSWORD_CHANGE'),
        'Password reset successfully! You can now login with your new password.',
      ).then((_) {
        Navigator.pop(context);
      });
    } else {
      String errorMsg = _getErrorMessage(result['msg']);
      mostrarAlerta(
        context,
        AppLocalizations.of(context)!.translate('ERROR'),
        errorMsg,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 20, top: 40, right: 20, bottom: 20),
      alignment: Alignment.center,
      decoration: BoxDecoration(
          color: background,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          )),
      child: Column(
        children: <Widget>[
          const SizedBox(height: 10),
          // Step indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStepIndicator(1, 'Email'),
              Container(width: 20, height: 2, color: _currentStep >= 2 ? primary : gris),
              _buildStepIndicator(2, 'OTP'),
              Container(width: 20, height: 2, color: _currentStep >= 3 ? primary : gris),
              _buildStepIndicator(3, 'Password'),
            ],
          ),
          const SizedBox(height: 30),

          // Step 1: Email
          if (_currentStep == 1) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22),
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
                textInputAction: TextInputAction.done,
                style: TextStyle(
                  fontFamily: 'roboto-medium',
                  letterSpacing: 1.0,
                  color: text_color,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
                autocorrect: false,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(right: 18),
                    child: Icon(Icons.mail_rounded, color: primary),
                  ),
                  labelText: AppLocalizations.of(context)!.translate('EMAIL'),
                  labelStyle: TextStyle(
                    fontFamily: 'roboto-regular',
                    letterSpacing: 1.0,
                    fontWeight: FontWeight.normal,
                    color: gris,
                    fontSize: 20,
                  ),
                  focusedBorder: InputBorder.none,
                  border: InputBorder.none,
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.only(left: 15),
              child: GestureDetector(
                child: CheckboxListTile(
                  activeColor: primary,
                  title: Text(
                    AppLocalizations.of(context)!.translate('ACCEPT_TERMS'),
                    style: TextStyle(
                      fontFamily: 'roboto-medium',
                      letterSpacing: 1.0,
                      color: text_color,
                      fontSize: 14,
                    ),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _checked,
                  onChanged: (value) {
                    setState(() {
                      _checked = value!;
                    });
                  },
                ),
                onTap: () {
                  launch(Environment.urlTerminos);
                },
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ButtonStyle(
                elevation: WidgetStateProperty.all(10),
                backgroundColor: WidgetStateProperty.all(
                  _isStep1Valid() && _checked && !_sendingOTP
                      ? primary
                      : gris.withOpacity(0.8),
                ),
                shape: WidgetStateProperty.all(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
              onPressed: (_isStep1Valid() && _checked && !_sendingOTP)
                  ? _sendResetOTP
                  : null,
              child: SizedBox(
                width: 240,
                height: 53,
                child: Center(
                  child: _sendingOTP
                      ? CircularProgressIndicator(color: drawer_white)
                      : Text(
                          AppLocalizations.of(context)!.translate('RECOVERY'),
                          style: TextStyle(
                            fontFamily: 'roboto-medium',
                            letterSpacing: 1.0,
                            color: drawer_white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),
          ],

          // Step 2: OTP Verification
          if (_currentStep == 2) ...[
            Text(
              'Enter the 6-digit OTP code sent to ${emailCtrl.text.trim()}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'roboto-medium',
                color: text_color,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: PinCodeTextField(
                appContext: context,
                length: 6,
                controller: otpCtrl,
                showCursor: true,
                cursorColor: primary,
                pinTheme: PinTheme(
                  shape: PinCodeFieldShape.box,
                  borderRadius: BorderRadius.circular(10.0),
                  fieldHeight: 50.0,
                  fieldWidth: 40.0,
                  activeFillColor: Colors.transparent,
                  inactiveFillColor: Colors.transparent,
                  selectedFillColor: Colors.transparent,
                  activeColor: primary,
                  inactiveColor: gris,
                  selectedColor: primary,
                ),
                enableActiveFill: false,
                onChanged: (value) {
                  setState(() {
                    _otpError = null;
                  });
                },
                onCompleted: (value) {
                  _verifyResetOTP();
                },
              ),
            ),
            if (_otpError != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _otpError!,
                  style: TextStyle(color: rojo, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: _sendingOTP ? null : _sendResetOTP,
                  child: Text(
                    'Resend OTP',
                    style: TextStyle(color: primary),
                  ),
                ),
              ],
            ),
            ElevatedButton(
              style: ButtonStyle(
                elevation: WidgetStateProperty.all(10),
                backgroundColor: WidgetStateProperty.all(
                  _isStep2Valid() && !_verifyingOTP
                      ? primary
                      : gris.withOpacity(0.8),
                ),
                shape: WidgetStateProperty.all(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
              onPressed: (_isStep2Valid() && !_verifyingOTP)
                  ? _verifyResetOTP
                  : null,
              child: SizedBox(
                width: 240,
                height: 53,
                child: Center(
                  child: _verifyingOTP
                      ? CircularProgressIndicator(color: drawer_white)
                      : Text(
                          'Verify OTP',
                          style: TextStyle(
                            fontFamily: 'roboto-medium',
                            letterSpacing: 1.0,
                            color: drawer_white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),
          ],

          // Step 3: New Password
          if (_currentStep == 3) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              margin: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
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
                textInputAction: TextInputAction.next,
                style: TextStyle(
                  fontFamily: 'roboto-medium',
                  letterSpacing: 1.0,
                  color: text_color,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
                autocorrect: false,
                obscureText: true,
                decoration: InputDecoration(
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(right: 18),
                    child: Icon(Icons.vpn_key_rounded, color: primary),
                  ),
                  labelText: AppLocalizations.of(context)!.translate('PASSWORD'),
                  labelStyle: TextStyle(
                    fontFamily: 'roboto-regular',
                    letterSpacing: 1.0,
                    fontWeight: FontWeight.normal,
                    color: gris,
                    fontSize: 20,
                  ),
                  focusedBorder: InputBorder.none,
                  border: InputBorder.none,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              margin: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
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
                controller: pass2Ctrl,
                textInputAction: TextInputAction.done,
                style: TextStyle(
                  fontFamily: 'roboto-medium',
                  letterSpacing: 1.0,
                  color: text_color,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
                autocorrect: false,
                obscureText: true,
                decoration: InputDecoration(
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(right: 18),
                    child: Icon(Icons.vpn_key_rounded, color: primary),
                  ),
                  labelText:
                      AppLocalizations.of(context)!.translate('REPEAT_PASSWORD'),
                  labelStyle: TextStyle(
                    fontFamily: 'roboto-regular',
                    letterSpacing: 1.0,
                    fontWeight: FontWeight.normal,
                    color: gris,
                    fontSize: 20,
                  ),
                  focusedBorder: InputBorder.none,
                  border: InputBorder.none,
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.only(left: 15),
              child: GestureDetector(
                child: CheckboxListTile(
                  activeColor: primary,
                  title: Text(
                    AppLocalizations.of(context)!.translate('ACCEPT_TERMS'),
                    style: TextStyle(
                      fontFamily: 'roboto-medium',
                      letterSpacing: 1.0,
                      color: text_color,
                      fontSize: 14,
                    ),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _checked,
                  onChanged: (value) {
                    setState(() {
                      _checked = value!;
                    });
                  },
                ),
                onTap: () {
                  launch(Environment.urlTerminos);
                },
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ButtonStyle(
                elevation: WidgetStateProperty.all(10),
                backgroundColor: WidgetStateProperty.all(
                  _isStep3Valid() && !_resettingPassword
                      ? primary
                      : gris.withOpacity(0.8),
                ),
                shape: WidgetStateProperty.all(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
              onPressed: (_isStep3Valid() && !_resettingPassword)
                  ? _resetPassword
                  : null,
              child: SizedBox(
                width: 240,
                height: 53,
                child: Center(
                  child: _resettingPassword
                      ? CircularProgressIndicator(color: drawer_white)
                      : Text(
                          'Reset Password',
                          style: TextStyle(
                            fontFamily: 'roboto-medium',
                            letterSpacing: 1.0,
                            color: drawer_white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 70),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
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
                    width: 60,
                    height: 50,
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int step, String label) {
    bool isActive = _currentStep >= step;
    return Column(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? primary : gris,
          ),
          child: Center(
            child: Text(
              '$step',
              style: TextStyle(
                color: blanco,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isActive ? primary : gris,
          ),
        ),
      ],
    );
  }
}
