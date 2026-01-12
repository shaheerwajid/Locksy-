import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:CryptoChat/global/AppLocalizations.dart';
import 'package:CryptoChat/helpers/style.dart';
import 'package:CryptoChat/services/auth_service.dart';
import 'package:CryptoChat/services/usuarios_service.dart';

class WelcomeOverlayWidget extends StatelessWidget {
  final AuthService authService;
  final VoidCallback onComplete;

  const WelcomeOverlayWidget({
    Key? key,
    required this.authService,
    required this.onComplete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final usuarioService = UsuariosService();

    return Container(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 100,
              backgroundColor: transparente,
              child: ClipOval(
                child: Image.asset(
                  'assets/banner/icon_img.png',
                  width: 100,
                  fit: BoxFit.fill,
                  color: amarillo,
                ),
              ),
            ),
            Text(
              AppLocalizations.of(context)!.translate('WELCOME'),
              style: const TextStyle(fontSize: 25),
            ),
            const SizedBox(height: 30),
            MaterialButton(
              color: amarillo,
              onPressed: () async {
                await Navigator.pushNamed(context, 'preguntas');

                // Mark security questions as completed
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool(
                    'hasSkippedOrCompletedSecurityQuestions', true);

                onComplete();
              },
              child: Text(
                AppLocalizations.of(context)!.translate('CONTINUE'),
                style: TextStyle(color: blanco, fontSize: 18),
              ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              child: Text(
                AppLocalizations.of(context)!.translate('SKIP'),
                style: TextStyle(
                  color: gris,
                  fontSize: 18,
                  decoration: TextDecoration.underline,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () async {
                // Mark security questions as skipped
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool(
                    'hasSkippedOrCompletedSecurityQuestions', true);

                // Update backend to mark user as not new
                try {
                  await usuarioService.infoUserChange(
                      'false', 'new', authService.usuario!.uid);
                  authService.usuario!.nuevo = 'false';
                } catch (e) {
                  print('Error updating nuevo status: $e');
                  // Continue anyway - local state is updated
                }

                onComplete();
              },
            ),
          ],
        ),
      ),
    );
  }
}

