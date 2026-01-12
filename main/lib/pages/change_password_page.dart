import 'package:flutter/material.dart';
import 'package:CryptoChat/global/AppLocalizations.dart';
import 'package:CryptoChat/helpers/style.dart';
import 'package:CryptoChat/services/auth_service.dart';
import 'package:CryptoChat/widgets/mostrar_alerta.dart';
import 'package:provider/provider.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  _ChangePasswordPageState createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _repeatPasswordCtrl = TextEditingController();
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureRepeatPassword = true;
  bool _isChanging = false;

  @override
  void dispose() {
    _currentPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _repeatPasswordCtrl.dispose();
    super.dispose();
  }

  bool _isFormValid() {
    return _currentPasswordCtrl.text.trim().isNotEmpty &&
        _newPasswordCtrl.text.trim().isNotEmpty &&
        _repeatPasswordCtrl.text.trim().isNotEmpty &&
        _newPasswordCtrl.text == _repeatPasswordCtrl.text;
  }

  String _getErrorMessage(String? errorCode) {
    switch (errorCode) {
      case 'ERR103':
        return 'Current password is incorrect. Please try again.';
      case 'ERR102':
      default:
        return 'An error occurred. Please try again later.';
    }
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_newPasswordCtrl.text != _repeatPasswordCtrl.text) {
      mostrarAlerta(
        context,
        AppLocalizations.of(context)!.translate('ERROR'),
        AppLocalizations.of(context)!.translate('MSG_INVALID_PASSWORD'),
      );
      return;
    }

    if (_newPasswordCtrl.text.length < 6) {
      mostrarAlerta(
        context,
        AppLocalizations.of(context)!.translate('ERROR'),
        'Password must be at least 6 characters long.',
      );
      return;
    }

    setState(() {
      _isChanging = true;
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    final result = await authService.changePassword(
      _currentPasswordCtrl.text.trim(),
      _newPasswordCtrl.text.trim(),
    );

    setState(() {
      _isChanging = false;
    });

    if (result['success'] == true) {
      mostrarAlerta(
        context,
        AppLocalizations.of(context)!.translate('PASSWORD_CHANGE'),
        'Password changed successfully!',
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

  void _navigateToForgotPassword() {
    Navigator.pushNamed(context, 'recovery');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        shadowColor: sub_header,
        backgroundColor: header,
        leading: InkWell(
          child: Icon(
            Icons.arrow_back_ios_rounded,
            color: background,
          ),
          onTap: () => Navigator.pop(context),
        ),
        title: Text(
          'Change Password',
          style: TextStyle(color: background),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                // Current Password
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
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
                  child: TextFormField(
                    controller: _currentPasswordCtrl,
                    obscureText: _obscureCurrentPassword,
                    textInputAction: TextInputAction.next,
                    style: TextStyle(
                      fontFamily: 'roboto-medium',
                      letterSpacing: 1.0,
                      color: text_color,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                    decoration: InputDecoration(
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(right: 18),
                        child: Icon(Icons.lock_outline, color: primary),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureCurrentPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: gris,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureCurrentPassword = !_obscureCurrentPassword;
                          });
                        },
                      ),
                      labelText: 'Current Password',
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
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Current password is required';
                      }
                      return null;
                    },
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(height: 20),
                // New Password
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
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
                  child: TextFormField(
                    controller: _newPasswordCtrl,
                    obscureText: _obscureNewPassword,
                    textInputAction: TextInputAction.next,
                    style: TextStyle(
                      fontFamily: 'roboto-medium',
                      letterSpacing: 1.0,
                      color: text_color,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                    decoration: InputDecoration(
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(right: 18),
                        child: Icon(Icons.vpn_key_rounded, color: primary),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureNewPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: gris,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureNewPassword = !_obscureNewPassword;
                          });
                        },
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
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'New password is required';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(height: 20),
                // Repeat Password
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
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
                  child: TextFormField(
                    controller: _repeatPasswordCtrl,
                    obscureText: _obscureRepeatPassword,
                    textInputAction: TextInputAction.done,
                    style: TextStyle(
                      fontFamily: 'roboto-medium',
                      letterSpacing: 1.0,
                      color: text_color,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                    decoration: InputDecoration(
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(right: 18),
                        child: Icon(Icons.vpn_key_rounded, color: primary),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureRepeatPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: gris,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureRepeatPassword = !_obscureRepeatPassword;
                          });
                        },
                      ),
                      labelText: AppLocalizations.of(context)!.translate('REPEAT_PASSWORD'),
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
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please repeat your new password';
                      }
                      if (value != _newPasswordCtrl.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(height: 30),
                // Forgot Password Link
                Center(
                  child: TextButton(
                    onPressed: _navigateToForgotPassword,
                    child: Text(
                      'Forgot your current password?',
                      style: TextStyle(
                        color: primary,
                        fontSize: 16,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Change Password Button
                ElevatedButton(
                  style: ButtonStyle(
                    elevation: WidgetStateProperty.all(10),
                    backgroundColor: WidgetStateProperty.all(
                      _isFormValid() && !_isChanging
                          ? primary
                          : gris.withOpacity(0.8),
                    ),
                    shape: WidgetStateProperty.all(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ),
                  onPressed: (_isFormValid() && !_isChanging)
                      ? _changePassword
                      : null,
                  child: SizedBox(
                    height: 53,
                    child: Center(
                      child: _isChanging
                          ? CircularProgressIndicator(color: drawer_white)
                          : Text(
                              'Change Password',
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
            ),
          ),
        ),
      ),
    );
  }
}

