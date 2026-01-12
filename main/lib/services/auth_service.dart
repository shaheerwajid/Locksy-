import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:CryptoChat/providers/ChatProvider.dart';
import 'package:CryptoChat/providers/GroupProvider.dart';
import 'package:CryptoChat/services/crypto.dart';
import 'package:CryptoChat/services/socket_service.dart';
import 'package:date_format/date_format.dart';

import 'package:video_compress/video_compress.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as pathPKG;
import 'package:pointycastle/api.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:CryptoChat/global/environment.dart';
import 'package:CryptoChat/helpers/funciones.dart';
import 'package:CryptoChat/helpers/duration_helper.dart';
import 'package:CryptoChat/models/contacto.dart';
import 'package:CryptoChat/models/grupo.dart';

import 'package:CryptoChat/models/login_response.dart';
import 'package:CryptoChat/models/mensajes_response.dart';
import 'package:CryptoChat/models/objPago.dart';
import 'package:CryptoChat/models/pago.dart';
import 'package:CryptoChat/models/usuario.dart';
import 'package:CryptoChat/providers/db_provider.dart';
import 'package:CryptoChat/widgets/chat_message.dart';
import 'package:CryptoChat/push_providers/push_notifications.dart';

class AuthService extends ChangeNotifier {
  Usuario? usuario;
  bool _autenticando = false;
  String? localPath;

  bool _cargando = false;

  bool get cargando => _cargando;

  set myBooleanValue(bool newValue) {
    _cargando = newValue;
    _streamController.add(newValue);
    notifyListeners();
  }

  void toggleBooleanValue(bool value) {
    _cargando = value;
    _streamController.add(value);
    notifyListeners();
  }

  final StreamController<bool> _streamController =
      StreamController<bool>.broadcast();

  Stream<bool> get booleanStream => _streamController.stream;

  @override
  void dispose() {
    _streamController.close();
    super.dispose();
  }

  // CRITICAL: Configure FlutterSecureStorage with Android options for release builds
  // Using default settings (not EncryptedSharedPreferences) for better compatibility
  // EncryptedSharedPreferences can fail on cold start due to Keystore issues
  // IMPORTANT: resetOnError MUST be false - if true, any transient error will wipe all tokens!
  static const _androidOptions = AndroidOptions(
    // CRITICAL FIX: Use regular secure storage instead of EncryptedSharedPreferences
    // EncryptedSharedPreferences can fail silently on app cold start due to Android Keystore issues
    encryptedSharedPreferences:
        false, // Use regular KeyStore-backed storage (more reliable)
    resetOnError:
        false, // CRITICAL: Must be false to prevent accidental data loss
  );

  static const _iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock,
  );

  final _storage = const FlutterSecureStorage(
    aOptions: _androidOptions,
    iOptions: _iosOptions,
  );

  bool get autenticando => _autenticando;
  set autenticando(bool valor) {
    _autenticando = valor;
    notifyListeners();
  }

  // Getters del token de forma estática
  // CRITICAL: All static methods must use the same Android/iOS options for consistency
  static Future<String> getToken() async {
    try {
      const storage = FlutterSecureStorage(
        aOptions: _androidOptions,
        iOptions: _iosOptions,
      );
      final token = await storage.read(key: 'token');
      if (token == null) return " ";
      return token;
    } catch (e) {
      debugPrint('[AUTH-STATIC] ❌ Error reading token: $e');
      return " ";
    }
  }

  static Future<String> getLocalPath() async {
    return (await getApplicationDocumentsDirectory()).path;
  }

  static Future<void> deleteToken() async {
    try {
      const storage = FlutterSecureStorage(
        aOptions: _androidOptions,
        iOptions: _iosOptions,
      );
      await storage.delete(key: 'token');
    } catch (e) {
      debugPrint('[AUTH-STATIC] ❌ Error deleting token: $e');
    }
  }

  static Future<void> deleteKeys() async {
    try {
      const storage = FlutterSecureStorage(
        aOptions: _androidOptions,
        iOptions: _iosOptions,
      );
      await storage.delete(key: 'privateKey');
      await storage.delete(key: 'publicKey');
    } catch (e) {
      debugPrint('[AUTH-STATIC] ❌ Error deleting keys: $e');
    }
  }

  Future<bool> login(String email, String password) async {
    try {
      debugPrint('[LOGIN] Starting login for: $email');
      autenticando = true;

      // Get FCM token BEFORE login (so we can send it with login request)
      String? fcmToken;
      try {
        final pushProvider = PushNotifications();
        fcmToken = await pushProvider.initNotifications();
        if (fcmToken != null && fcmToken.isNotEmpty) {
          debugPrint(
              '[LOGIN] ✅ FCM token obtained: ${fcmToken.substring(0, 20)}...');
        } else {
          debugPrint('[LOGIN] ⚠️ FCM token is null or empty');
        }
      } catch (e) {
        debugPrint('[LOGIN] ⚠️ Error getting FCM token: $e');
        // Continue with login even if FCM fails
      }

      // Include fcmToken in login request
      final data = {
        'email': email,
        'password': password,
        if (fcmToken != null && fcmToken.isNotEmpty) 'fcmToken': fcmToken,
      };

      debugPrint('[LOGIN] Sending request to: ${Environment.apiUrl}/login');
      final resp = await http.post(
        Uri.parse('${Environment.apiUrl}/login'),
        body: jsonEncode(data),
        headers: {'Content-Type': 'application/json'},
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('[LOGIN] Request timeout after 30 seconds');
          throw TimeoutException('Login request timeout');
        },
      );

      debugPrint('[LOGIN] Received response with status: ${resp.statusCode}');
      autenticando = false;
      localPath = (await getApplicationDocumentsDirectory()).path;

      if (resp.statusCode == 200) {
        print('[LOGIN] Parsing response JSON...');
        print('[LOGIN] Response body: ${resp.body}');

        try {
          final loginResponse = loginResponseFromJson(resp.body);

          // Check if login was successful
          if (loginResponse.ok != true) {
            print('[LOGIN] Login failed: ok is false in response');
            print('[LOGIN] Response ok value: ${loginResponse.ok}');
            return false;
          }

          if (loginResponse.usuario == null) {
            print('[LOGIN] ERROR: usuario is null in response');
            return false;
          }

          if (loginResponse.token == null || loginResponse.token!.isEmpty) {
            print('[LOGIN] ERROR: token is null or empty');
            print('[LOGIN] Token value: ${loginResponse.token}');
            print('[LOGIN] Response keys: ${jsonDecode(resp.body).keys}');
            return false;
          }

          usuario = loginResponse.usuario;
          print('[LOGIN] Usuario loaded: ${usuario!.nombre}');
          print('[LOGIN] nuevo status: ${usuario!.nuevo}');
          print(
              '[LOGIN] privateKey in response: ${usuario!.privateKey != null && usuario!.privateKey!.isNotEmpty ? "YES (length: ${usuario!.privateKey!.length})" : "NO"}');
          print(
              '[LOGIN] publicKey in response: ${usuario!.publicKey != null && usuario!.publicKey!.isNotEmpty ? "YES (length: ${usuario!.publicKey!.length})" : "NO"}');

          // Handle privateKey: Backend now sends decrypted privateKey on every login (password-encrypted storage)
          // If it's in the response, use it and save to secure storage. Otherwise, try to load from secure storage.
          if (usuario!.privateKey != null && usuario!.privateKey!.isNotEmpty) {
            print(
                '[LOGIN] ✅ privateKey found in response (decrypted from server), will save to secure storage');
          } else {
            print(
                '[LOGIN] ⚠️ privateKey not in response, loading from secure storage...');
            final storedPrivateKey = await _storage.read(key: 'privateKey');
            if (storedPrivateKey != null && storedPrivateKey.isNotEmpty) {
              usuario!.privateKey = storedPrivateKey;
              print(
                  '[LOGIN] ✅ privateKey loaded from secure storage (length: ${storedPrivateKey.length})');
            } else {
              print(
                  '[LOGIN] ❌ WARNING: No privateKey found in response or storage');
              print(
                  '[LOGIN] User may need to regenerate keys or this is an older account without encrypted key storage');
            }
          }

          print('[LOGIN] Saving token...');
          await _guardarToken(loginResponse.token!);
          print('[LOGIN] Token saved');

          // FCM token was already sent in login request, but send again as backup
          // (Backend should have saved it, but ensure it's saved via dedicated endpoint too)
          if (fcmToken != null && fcmToken.isNotEmpty) {
            // Send in background - don't block login
            Future.microtask(() async {
              try {
                await updateFCMTokenToBackend(fcmToken!);
                debugPrint('[LOGIN] ✅ FCM token backup registration completed');
              } catch (e) {
                debugPrint(
                    '[LOGIN] ⚠️ FCM token backup registration failed: $e');
                // Non-critical, don't fail login
              }
            });
          }

          // Save keys with null checks and await
          print('[LOGIN] Saving keys to secure storage...');
          if (usuario!.privateKey != null && usuario!.privateKey!.isNotEmpty) {
            await _savePrivateKey(usuario!.privateKey!);
            print(
                '[LOGIN] ✅ Private key saved to secure storage (length: ${usuario!.privateKey!.length})');
          } else {
            print(
                '[LOGIN] ❌ WARNING: Cannot save privateKey - it is null or empty');
            // Generate new keys if missing (for old accounts without encryptedPrivateKey)
            print('[LOGIN] 🔄 Generating new keys for user...');
            try {
              Set<String> keys = LocalCrypto().generatePaireKey();
              String publicKeyString = keys.first; // ASN.1 format
              String privateKeyString = keys.last; // ASN.1 format

              // Convert to PEM format for backend
              String publicKeyPEM =
                  LocalCrypto().publicKeyToPEM(publicKeyString);

              // Save keys locally first
              usuario!.privateKey = privateKeyString;
              usuario!.publicKey = publicKeyPEM;
              await _savePrivateKey(privateKeyString);
              await _savepublicKey(publicKeyPEM);
              print('[LOGIN] ✅ New keys generated and saved locally');

              // Send keys to backend to encrypt and store (async, don't block login)
              // Store password temporarily for key update
              final passwordForKeys = password;
              Future.microtask(() async {
                try {
                  print(
                      '[LOGIN-BG] Sending new keys to backend for encryption...');
                  await _updateKeysOnBackend(
                      publicKeyPEM, privateKeyString, passwordForKeys);
                  print('[LOGIN-BG] ✅ Keys successfully stored on backend');
                } catch (e) {
                  print('[LOGIN-BG] ❌ Error storing keys on backend: $e');
                  // Keys are saved locally, so user can still use the app
                }
              });
            } catch (e, stackTrace) {
              print('[LOGIN] ❌ ERROR generating new keys: $e');
              print('[LOGIN] Stack trace: $stackTrace');
            }
          }

          if (usuario!.publicKey != null && usuario!.publicKey!.isNotEmpty) {
            // Just store whatever format the backend sends (PEM or ASN.1)
            // stringToPublicKey will handle both formats transparently
            print(
                '[LOGIN] Saving public key (length: ${usuario!.publicKey!.length})');
            await _savepublicKey(usuario!.publicKey!);
            print('[LOGIN] ✅ Public key saved to secure storage');
          } else {
            print(
                '[LOGIN] ❌ WARNING: Cannot save publicKey - it is null or empty');
          }

          // Post-login operations - make them non-blocking so login completes quickly
          // These can run in background and won't block the login flow
          // Socket connection is handled by the app's Provider setup, so we don't need to connect here
          print('[LOGIN] Starting background operations (pagos, contactos)...');

          // Load pagos in background
          Future.microtask(() async {
            try {
              print('[LOGIN-BG] Loading pagos...');
              await pagosUsuario(usuario!);
              print('[LOGIN-BG] Pagos loaded');
            } catch (e) {
              print('[LOGIN-BG] Error loading pagos: $e');
            }
          });

          // Load contactos in background
          Future.microtask(() async {
            try {
              print('[LOGIN-BG] Loading contactos...');
              await guardarContactosLocales(usuario!.codigoContacto);
              print('[LOGIN-BG] Contactos loaded');
            } catch (e) {
              print('[LOGIN-BG] Error loading contactos: $e');
            }
          });

          // Note: Socket connection is handled by the app's Provider setup
          // It will connect automatically when SocketService is accessed via Provider
          // This allows UI to render first, improving perceived performance

          print('[LOGIN] Login successful!');
          return true;
        } catch (e, stackTrace) {
          print('[LOGIN] ERROR parsing response: $e');
          print('[LOGIN] Stack trace: $stackTrace');
          print('[LOGIN] Raw response body: ${resp.body}');
          return false;
        }
      } else {
        debugPrint('[LOGIN] Failed with status: ${resp.statusCode}');
        debugPrint('[LOGIN] Response body: ${resp.body}');
        // Try to extract error message from response
        try {
          final respBody = jsonDecode(resp.body);
          if (respBody['msg'] != null) {
            debugPrint('[LOGIN] Error message: ${respBody['msg']}');
          }
        } catch (e) {
          debugPrint('[LOGIN] Could not parse error response');
        }
        return false;
      }
    } catch (e, stackTrace) {
      // CRITICAL: Always reset autenticando on error
      autenticando = false;
      debugPrint('[LOGIN] EXCEPTION: $e');
      debugPrint('[LOGIN] Stack trace: $stackTrace');
      return false;
    }
  }



  // Forgot Password - Send OTP for password reset
  Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      debugPrint('[PASSWORD RESET] Sending reset OTP to: $email');
      final data = {
        'email': email,
      };

      debugPrint(
          '[PASSWORD RESET] Sending request to: ${Environment.apiUrl}/login/forgot-password');
      final resp = await http.post(
        Uri.parse('${Environment.apiUrl}/login/forgot-password'),
        body: jsonEncode(data),
        headers: {'Content-Type': 'application/json'},
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('[PASSWORD RESET] Request timeout after 30 seconds');
          throw TimeoutException('Forgot password request timeout');
        },
      );

      debugPrint(
          '[PASSWORD RESET] Received response with status: ${resp.statusCode}');
      final respBody = jsonDecode(resp.body);

      if (resp.statusCode == 200 && respBody['ok'] == true) {
        debugPrint('[PASSWORD RESET] Reset OTP sent successfully');
        return {
          'success': true,
          'msg': respBody['msg'] ?? 'If the email exists, an OTP has been sent',
          'expiresIn': respBody['expiresIn'] ?? 15,
        };
      } else {
        debugPrint(
            '[PASSWORD RESET] Failed to send reset OTP: ${respBody['msg']}');
        return {
          'success': false,
          'msg': respBody['msg'] ?? 'ERR102',
        };
      }
    } catch (e, stackTrace) {
      debugPrint('[PASSWORD RESET] EXCEPTION: $e');
      debugPrint('[PASSWORD RESET] Stack trace: $stackTrace');
      return {
        'success': false,
        'msg': 'ERR102',
      };
    }
  }

  // Verify Password Reset OTP
  Future<Map<String, dynamic>> verifyResetOTP(
      String email, String otpCode) async {
    try {
      debugPrint('[PASSWORD RESET] Verifying reset OTP for: $email');
      final data = {
        'email': email,
        'otpCode': otpCode,
      };

      debugPrint(
          '[PASSWORD RESET] Sending request to: ${Environment.apiUrl}/login/verify-reset-otp');
      final resp = await http.post(
        Uri.parse('${Environment.apiUrl}/login/verify-reset-otp'),
        body: jsonEncode(data),
        headers: {'Content-Type': 'application/json'},
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('[PASSWORD RESET] Request timeout after 30 seconds');
          throw TimeoutException('Verify reset OTP request timeout');
        },
      );

      debugPrint(
          '[PASSWORD RESET] Received response with status: ${resp.statusCode}');
      final respBody = jsonDecode(resp.body);

      if (resp.statusCode == 200 && respBody['ok'] == true) {
        debugPrint('[PASSWORD RESET] Reset OTP verified successfully');
        return {
          'success': true,
          'msg': respBody['msg'] ?? 'Reset OTP verified successfully',
        };
      } else {
        debugPrint(
            '[PASSWORD RESET] Reset OTP verification failed: ${respBody['msg']}');
        return {
          'success': false,
          'msg': respBody['msg'] ?? 'ERR102',
          'attemptsRemaining': respBody['attemptsRemaining'],
        };
      }
    } catch (e, stackTrace) {
      debugPrint('[PASSWORD RESET] EXCEPTION: $e');
      debugPrint('[PASSWORD RESET] Stack trace: $stackTrace');
      return {
        'success': false,
        'msg': 'ERR102',
      };
    }
  }

  // Reset Password - After OTP verification
  Future<Map<String, dynamic>> resetPassword(
      String email, String newPassword, String otpCode) async {
    try {
      debugPrint('[PASSWORD RESET] Resetting password for: $email');
      final data = {
        'email': email,
        'newPassword': newPassword,
        'otpCode': otpCode,
      };

      debugPrint(
          '[PASSWORD RESET] Sending request to: ${Environment.apiUrl}/login/reset-password');
      final resp = await http.post(
        Uri.parse('${Environment.apiUrl}/login/reset-password'),
        body: jsonEncode(data),
        headers: {'Content-Type': 'application/json'},
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('[PASSWORD RESET] Request timeout after 30 seconds');
          throw TimeoutException('Reset password request timeout');
        },
      );

      debugPrint(
          '[PASSWORD RESET] Received response with status: ${resp.statusCode}');
      final respBody = jsonDecode(resp.body);

      if (resp.statusCode == 200 && respBody['ok'] == true) {
        debugPrint('[PASSWORD RESET] Password reset successfully');
        return {
          'success': true,
          'msg': respBody['msg'] ?? 'Password reset successfully',
        };
      } else {
        debugPrint(
            '[PASSWORD RESET] Password reset failed: ${respBody['msg']}');
        return {
          'success': false,
          'msg': respBody['msg'] ?? 'ERR102',
        };
      }
    } catch (e, stackTrace) {
      debugPrint('[PASSWORD RESET] EXCEPTION: $e');
      debugPrint('[PASSWORD RESET] Stack trace: $stackTrace');
      return {
        'success': false,
        'msg': 'ERR102',
      };
    }
  }

  // Change Password - With current password
  Future<Map<String, dynamic>> changePassword(
      String currentPassword, String newPassword) async {
    try {
      debugPrint(
          '[CHANGE PASSWORD] Changing password for user: ${usuario?.uid}');

      final data = {
        'uid': usuario!.uid,
        'clave': cifrarPMS(newPassword),
        'oldClave': cifrarPMS(currentPassword),
      };

      debugPrint(
          '[CHANGE PASSWORD] Sending request to: ${Environment.apiUrl}/usuarios/updateUsuario');
      final resp = await http.post(
        Uri.parse('${Environment.apiUrl}/usuarios/updateUsuario'),
        body: jsonEncode(data),
        headers: {
          'Content-Type': 'application/json',
          'x-token': await AuthService.getToken(),
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('[CHANGE PASSWORD] Request timeout after 30 seconds');
          throw TimeoutException('Change password request timeout');
        },
      );

      debugPrint(
          '[CHANGE PASSWORD] Received response with status: ${resp.statusCode}');
      final respBody = jsonDecode(resp.body);

      if (resp.statusCode == 200 &&
          respBody['ok'] != false &&
          respBody['error'] != 'ERR103') {
        debugPrint('[CHANGE PASSWORD] Password changed successfully');
        return {
          'success': true,
          'msg': respBody['ok'] ?? 'Password changed successfully',
        };
      } else {
        String errorMsg = respBody['error'] ?? respBody['msg'] ?? 'ERR102';
        debugPrint('[CHANGE PASSWORD] Password change failed: $errorMsg');
        return {
          'success': false,
          'msg': errorMsg,
        };
      }
    } catch (e, stackTrace) {
      debugPrint('[CHANGE PASSWORD] EXCEPTION: $e');
      debugPrint('[CHANGE PASSWORD] Stack trace: $stackTrace');
      return {
        'success': false,
        'msg': 'ERR102',
      };
    }
  }

  Future register(
      String nombre, String email, String password, String referCode) async {
    try {
      debugPrint('[REGISTER] Starting registration for: $email');
      var prefs = await SharedPreferences.getInstance();
      var lang = prefs.getString('language_code');
      lang = lang ?? "en";

      autenticando = true;

      Set<String> keys = LocalCrypto().generatePaireKey();
      String publicKeyString =
          keys.first; // ASN.1 format (for Flutter internal use)

      // Convert to PEM format for backend validation
      // Backend expects PEM format, but Flutter uses ASN.1 internally
      String publicKeyPEM = LocalCrypto().publicKeyToPEM(publicKeyString);

      String encryptedprivateKeyString =
          LocalCrypto().encrypt('Cryp16Zbqc@#4D%8', keys.last);

      final data = {
        'nombre': nombre,
        'email': email,
        'password': password,
        'idioma': lang,
        'referido': referCode,
        'publicKey': publicKeyPEM, // Send PEM format to backend
        'privateKey': encryptedprivateKeyString,
      };

      debugPrint(
          '[REGISTER] Generated keys - ASN.1 length: ${publicKeyString.length}, PEM length: ${publicKeyPEM.length}');

      debugPrint(
          '[REGISTER] Sending request to: ${Environment.apiUrl}/login/new');
      final resp = await http.post(
        Uri.parse('${Environment.apiUrl}/login/new'),
        body: jsonEncode(data),
        headers: {'Content-Type': 'application/json'},
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('[REGISTER] Request timeout after 30 seconds');
          throw TimeoutException('Register request timeout');
        },
      );

      debugPrint(
          '[REGISTER] Received response with status: ${resp.statusCode}');
      autenticando = false;
      localPath = (await getApplicationDocumentsDirectory()).path;

      if (resp.statusCode == 200) {
        debugPrint('[REGISTER] Parsing response JSON...');
        final loginResponse = loginResponseFromJson(resp.body);

        // Check if registration was successful
        if (loginResponse.ok != true) {
          debugPrint('[REGISTER] Registration failed: ok is false');
          final respBody = jsonDecode(resp.body);
          return respBody['msg'] ?? 'ERR102';
        }

        if (loginResponse.usuario == null) {
          debugPrint('[REGISTER] ERROR: usuario is null in response');
          return 'ERR102';
        }

        if (loginResponse.token == null || loginResponse.token!.isEmpty) {
          debugPrint('[REGISTER] ERROR: token is null or empty');
          return 'ERR102';
        }

        usuario = loginResponse.usuario;
        debugPrint('[REGISTER] Usuario loaded: ${usuario!.nombre}');

        debugPrint('[REGISTER] Saving token...');
        await _guardarToken(loginResponse.token!);
        debugPrint('[REGISTER] Token saved');

        // Get and send FCM token to backend
        try {
          final pushProvider = PushNotifications();
          final fcmToken = await pushProvider.initNotifications();
          if (fcmToken != null && fcmToken.isNotEmpty) {
            await updateFCMTokenToBackend(fcmToken);
          }
        } catch (e) {
          debugPrint('[REGISTER] Error initializing FCM: $e');
          // Don't fail registration if FCM fails
        }

        debugPrint('[REGISTER] Saving keys...');
        await _savePrivateKey(keys.last);
        // Save public key in PEM format for consistency with login
        // (backend stores and returns PEM, so we should store PEM locally too)
        debugPrint(
            '[REGISTER] Saving public key (PEM format, length: ${publicKeyPEM.length})');
        await _savepublicKey(publicKeyPEM);
        debugPrint('[REGISTER] Keys saved');

        debugPrint('[REGISTER] Registration successful!');
        return true;
      } else {
        debugPrint('[REGISTER] Failed with status: ${resp.statusCode}');
        debugPrint('[REGISTER] Response body: ${resp.body}');
        final respBody = jsonDecode(resp.body);
        return respBody['msg'] ?? 'ERR102';
      }
    } catch (e, stackTrace) {
      // CRITICAL: Always reset autenticando on error
      autenticando = false;
      debugPrint('[REGISTER] EXCEPTION: $e');
      debugPrint('[REGISTER] Stack trace: $stackTrace');
      return 'ERR102';
    }
  }

  Future<AsymmetricKeyPair?> getKeys() async {
    final String? privateKey = await _storage.read(key: 'privateKey');
    final String? publicKey = await _storage.read(key: 'publicKey');

    // Check if keys exist in storage
    if (privateKey == null || privateKey.isEmpty) {
      print('[AUTH] WARNING: privateKey not found in storage');
      return null;
    }

    if (publicKey == null || publicKey.isEmpty) {
      print('[AUTH] WARNING: publicKey not found in storage');
      return null;
    }

    try {
      AsymmetricKeyPair key =
          LocalCrypto().getKeyPairFromString(privateKey, publicKey);
      return key;
    } catch (e) {
      print('[AUTH] ERROR: Failed to get key pair from strings: $e');
      return null;
    }
  }

  Future<bool> isLoggedIn() async {
    debugPrint('[AUTH] Checking if user is logged in...');
    debugPrint('[AUTH] Using Keystore-backed secure storage');

    String? token;

    // CRITICAL: Retry logic for release builds
    // Android Keystore can be temporarily unavailable on cold start
    const maxRetries = 3;
    const retryDelay = Duration(milliseconds: 200);

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint('[AUTH] Token read attempt $attempt/$maxRetries');
        token = await _storage.read(key: 'token');

        if (token != null && token.isNotEmpty && token.trim().isNotEmpty) {
          debugPrint(
              '[AUTH] ✅ Token found on attempt $attempt (length: ${token.length})');
          break; // Success!
        }

        if (attempt < maxRetries) {
          debugPrint(
              '[AUTH] Token null on attempt $attempt, retrying after delay...');
          await Future.delayed(retryDelay);
        }
      } catch (e, stackTrace) {
        debugPrint('[AUTH] ⚠️ Error on attempt $attempt: $e');

        if (attempt < maxRetries) {
          debugPrint('[AUTH] Retrying after delay...');
          await Future.delayed(retryDelay);
        } else {
          debugPrint('[AUTH] ❌ All $maxRetries attempts failed');
          debugPrint('[AUTH] Stack trace: $stackTrace');
          // Don't return false immediately - the token might exist but storage is failing
          // This can happen on cold start in release builds
        }
      }
    }

    // Final check after all retries
    if (token == null || token.isEmpty || token.trim().isEmpty) {
      debugPrint('[AUTH] No valid token found after $maxRetries attempts');
      return false;
    }

    debugPrint('[AUTH] Token found, validating with server...');

    debugPrint('[AUTH] Proceeding with server validation...');
    try {
      String url = '${Environment.apiUrl}/login/renew';
      final resp = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json', 'x-token': token},
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint(
              '[AUTH] Token validation timeout - assuming valid token exists');
          // On timeout, don't invalidate - just return false for this check
          // The user can still use the app if token exists
          throw TimeoutException('Token validation timeout');
        },
      );

      localPath = (await getApplicationDocumentsDirectory()).path;

      if (resp.statusCode == 200) {
        debugPrint('[AUTH] Token is valid - user is logged in');
        final loginResponse = loginResponseFromJson(resp.body);
        usuario = loginResponse.usuario;
        await _guardarToken(loginResponse.token!);

        // Load user data in background (don't block login)
        Future.microtask(() async {
          try {
            await pagosUsuario(usuario!);
            await guardarContactosLocales(usuario!.codigoContacto);
            _savePrivateKey(usuario!.privateKey!);
            _savepublicKey(usuario!.publicKey!);

            // Get and send FCM token
            try {
              final pushProvider = PushNotifications();
              final fcmToken = await pushProvider.initNotifications();
              if (fcmToken != null && fcmToken.isNotEmpty) {
                await updateFCMTokenToBackend(fcmToken);
              }
            } catch (e) {
              debugPrint('[AUTH] Error updating FCM token: $e');
            }
          } catch (e) {
            debugPrint('[AUTH] Error loading user data: $e');
            // Don't fail login if data loading fails
          }
        });

        return true;
      } else if (resp.statusCode == 401 || resp.statusCode == 403) {
        // Token is invalid/expired - clear it
        debugPrint(
            '[AUTH] Token is invalid (${resp.statusCode}) - logging out');
        logout();
        return false;
      } else {
        // Server error - don't invalidate token, just return false
        // User might still be logged in, but we can't verify right now
        debugPrint('[AUTH] Server error (${resp.statusCode}) - keeping token');
        return false;
      }
    } on TimeoutException {
      // Network timeout - if token exists, assume it's still valid
      // Don't force user to login again due to network issues
      debugPrint(
          '[AUTH] Token validation timeout - token exists, assuming still valid');
      debugPrint(
          '[AUTH] User will remain logged in (token will be validated on next request)');

      // Try to load local path and return true if token exists
      try {
        localPath = (await getApplicationDocumentsDirectory()).path;
      } catch (e) {
        debugPrint('[AUTH] Error getting local path: $e');
      }

      // Return true if token exists (assume valid until proven otherwise)
      return true;
    } catch (e) {
      // Other network errors - if token exists, assume it's still valid
      debugPrint('[AUTH] Network error validating token: $e');
      debugPrint(
          '[AUTH] Token exists - assuming still valid (will retry on next request)');

      // Try to load local path
      try {
        localPath = (await getApplicationDocumentsDirectory()).path;
      } catch (pathError) {
        debugPrint('[AUTH] Error getting local path: $pathError');
      }

      // Return true if token exists (don't force logout on network errors)
      return true;
    }
  }

  Future _guardarToken(String token) async {
    try {
      debugPrint('[AUTH] Saving token to secure storage...');
      await _storage.write(key: 'token', value: token);

      // Verify token was saved (CRITICAL for release builds)
      final savedToken = await _storage.read(key: 'token');
      if (savedToken == null || savedToken != token) {
        debugPrint(
            '[AUTH] ⚠️ Token save verification failed - token may not have been saved!');
        // Try saving again
        await _storage.write(key: 'token', value: token);
        final retryToken = await _storage.read(key: 'token');
        if (retryToken != null && retryToken == token) {
          debugPrint('[AUTH] ✅ Token saved successfully on retry');
        } else {
          debugPrint('[AUTH] ❌ Token save failed even after retry!');
        }
      } else {
        debugPrint('[AUTH] ✅ Token saved and verified successfully');
      }
    } catch (e, stackTrace) {
      debugPrint('[AUTH] ❌ Error saving token: $e');
      debugPrint('[AUTH] Stack trace: $stackTrace');
      rethrow; // Re-throw to let caller know save failed
    }
  }

  // Update FCM token to backend
  Future<void> updateFCMTokenToBackend(String fcmToken) async {
    try {
      if (usuario == null || usuario!.uid == null) {
        debugPrint('[FCM] Cannot update token: User not logged in');
        return;
      }

      if (fcmToken.isEmpty) {
        debugPrint('[FCM] Cannot update token: Token is empty');
        return;
      }

      debugPrint('[FCM] Sending FCM token to backend...');
      debugPrint('[FCM] Token length: ${fcmToken.length}');
      debugPrint('[FCM] Token preview: ${fcmToken.substring(0, 20)}...');
      debugPrint('[FCM] User UID: ${usuario!.uid}');

      // Use the dedicated register-fcm-token endpoint (more reliable)
      final resp = await http.post(
        Uri.parse('${Environment.apiUrl}/usuarios/register-fcm-token'),
        body: jsonEncode({'fcmToken': fcmToken}),
        headers: {
          'Content-Type': 'application/json',
          'x-token': await AuthService.getToken(),
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('[FCM] Request timeout');
          throw TimeoutException('FCM token update timeout');
        },
      );

      if (resp.statusCode == 200) {
        final respBody = jsonDecode(resp.body);
        if (respBody['ok'] == true) {
          debugPrint('[FCM] ✅ Token successfully registered with backend');
        } else {
          debugPrint('[FCM] ⚠️ Token registration failed: ${respBody['msg']}');
        }
      } else {
        debugPrint(
            '[FCM] ❌ Token registration failed with status: ${resp.statusCode}');
        debugPrint('[FCM] Response: ${resp.body}');
      }
    } catch (e) {
      debugPrint('[FCM] ❌ Error updating FCM token: $e');
      // Don't throw - this shouldn't block the app
    }
  }

  Future _savePrivateKey(String value) async {
    return await _storage.write(key: 'privateKey', value: value);
  }

  Future _savepublicKey(String value) async {
    return await _storage.write(key: 'publicKey', value: value);
  }

  // Update keys on backend (encrypt and store)
  Future<void> _updateKeysOnBackend(
      String publicKeyPEM, String privateKeyASN1, String password) async {
    try {
      final token = await getToken();
      if (token.trim().isEmpty) {
        print('[Auth] ❌ Cannot update keys: No token available');
        return;
      }

      final data = {
        'publicKey': publicKeyPEM,
        'privateKey': privateKeyASN1,
        'password': password, // Password is required to encrypt the private key
      };

      print(
          '[Auth] Sending keys update request to: ${Environment.apiUrl}/usuarios/me/keys');
      final resp = await http.post(
        Uri.parse('${Environment.apiUrl}/usuarios/me/keys'),
        body: jsonEncode(data),
        headers: {
          'Content-Type': 'application/json',
          'x-token': token,
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          print('[Auth] Keys update request timeout after 30 seconds');
          throw TimeoutException('Keys update request timeout');
        },
      );

      if (resp.statusCode == 200) {
        final respBody = jsonDecode(resp.body);
        if (respBody['ok'] == true) {
          print('[Auth] ✅ Keys successfully updated on backend');
        } else {
          print('[Auth] ❌ Keys update failed: ${respBody['msg']}');
        }
      } else {
        print('[Auth] ❌ Keys update failed with status: ${resp.statusCode}');
        print('[Auth] Response body: ${resp.body}');
      }
    } catch (e, stackTrace) {
      print('[Auth] ❌ ERROR updating keys on backend: $e');
      print('[Auth] Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future logout() async {
    // Clear token from secure storage
    await _storage.delete(key: 'token');
    
    // Clear cryptographic keys to prevent key leakage between accounts
    await _storage.delete(key: 'privateKey');
    await _storage.delete(key: 'publicKey');

    // Wipe local database completely
    await DBProvider.db.deleteAllData();

    // Clear user data in memory
    usuario = null;

    // Notify listeners that user has logged out
    notifyListeners();
  }

  pagosUsuario(Usuario usuario) async {
    List<Pago> pagosUsuario = await getListPagos(this.usuario!.uid!);
    if (pagosUsuario.isNotEmpty) {
      DBProvider.db.borrarPagos();
      for (var pago in pagosUsuario) {
        DBProvider.db.insertarPago(ObjPago(
            nombre: 'CryptoChat Subscription',
            fecha: pago.fechaFin,
            fechaPago: pago.fechaTransaccion,
            valor: pago.value));
      }
    }
  }

  Future<List<Pago>> getListPagos(String uid) async {
    try {
      final data = {'uid': uid};
      String url = '${Environment.apiUrl}/usuarios/getPagos';

      final resp = await http
          .post(
        Uri.parse(url),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          'x-token': await AuthService.getToken()
        },
        body: jsonEncode(data),
      )
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('[getListPagos] Request timeout after 10 seconds');
          throw TimeoutException('Request timeout');
        },
      );
      var json = jsonDecode(resp.body);
      List<dynamic> listaPagos = json["listPagos"];

      var map = listaPagos.map((e) => Pago.fromJson(e));
      List<Pago> pago = List<Pago>.from(map);
      return pago;
    } catch (e) {
      debugPrint('[getListPagos] Error: $e');
      return [];
    }
  }

  Future<List<Contacto>> getListContactos(String codeUsuario) async {
    try {
      final data = {'code': codeUsuario};
      String url = '${Environment.apiUrl}/contactos/getListadoContactos';

      final resp = await http
          .post(
        Uri.parse(url),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          'x-token': await AuthService.getToken()
        },
        body: jsonEncode(data),
      )
          .timeout(
        const Duration(seconds: 15), // Increased timeout
        onTimeout: () {
          debugPrint('[getListContactos] Request timeout after 15 seconds');
          debugPrint(
              '[getListContactos] Returning empty list to prevent blocking');
          return http.Response('{"listContactos": []}',
              200); // Return empty response instead of throwing
        },
      );

      // Check response status
      if (resp.statusCode != 200) {
        debugPrint('[getListContactos] Error: HTTP ${resp.statusCode}');
        debugPrint('[getListContactos] Response body: ${resp.body}');
        return [];
      }

      // Validate response body is JSON
      dynamic json;
      try {
        json = jsonDecode(resp.body);
      } catch (e) {
        debugPrint('[getListContactos] Error: Response is not valid JSON');
        debugPrint('[getListContactos] Response body: ${resp.body}');
        return [];
      }

      // Validate response structure
      if (json is! Map<String, dynamic>) {
        debugPrint('[getListContactos] Error: Response is not a Map');
        debugPrint('[getListContactos] Response type: ${json.runtimeType}');
        debugPrint('[getListContactos] Response body: ${resp.body}');
        return [];
      }

      // Check if listContactos exists and is a list
      if (json["listContactos"] == null) {
        debugPrint(
            '[getListContactos] Warning: listContactos is null in response');
        return [];
      }

      if (json["listContactos"] is! List) {
        debugPrint('[getListContactos] Error: listContactos is not a List');
        debugPrint(
            '[getListContactos] listContactos type: ${json["listContactos"].runtimeType}');
        return [];
      }

      List<dynamic> solicitudes = json["listContactos"];

      // Filter out invalid entries (strings, nulls, etc.) and only process valid maps
      List<Contacto> solicitud = [];
      for (var e in solicitudes) {
        try {
          if (e is Map<String, dynamic>) {
            // Validate that usuario and contacto are maps before parsing
            if (e['usuario'] is Map<String, dynamic> &&
                e['contacto'] is Map<String, dynamic>) {
              solicitud.add(Contacto.fromJson(e));
            } else {
              debugPrint(
                  '[getListContactos] Skipping invalid contacto entry - missing usuario/contacto maps');
            }
          } else {
            debugPrint(
                '[getListContactos] Skipping non-map entry: ${e.runtimeType}');
          }
        } catch (e, stackTrace) {
          debugPrint('[getListContactos] Error parsing contacto entry: $e');
          debugPrint('[getListContactos] Stack trace: $stackTrace');
          // Continue processing other entries
        }
      }

      // Log if any entries were filtered out
      if (solicitudes.length != solicitud.length) {
        debugPrint(
            '[getListContactos] Warning: Filtered out ${solicitudes.length - solicitud.length} invalid entries');
      }

      return solicitud;
    } catch (e, stackTrace) {
      debugPrint('[getListContactos] Error: $e');
      debugPrint('[getListContactos] Stack trace: $stackTrace');
      return [];
    }
  }

  guardarContactosLocales(codigo) async {
    try {
      // Run in background to avoid blocking UI
      final contactos = await getListContactos(codigo).timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          debugPrint(
              '[guardarContactosLocales] Timeout getting contacts, using empty list');
          return <Contacto>[];
        },
      );

      // Save contacts to database in batches to avoid locking
      for (Contacto c in contactos) {
        try {
          if (c.usuario != null && c.contacto != null) {
            final contactoToSave =
                c.usuario!.codigoContacto == codigo ? c.contacto! : c.usuario!;
            await DBProvider.db.nuevoContacto(contactoToSave);
          }
        } catch (e) {
          debugPrint('[guardarContactosLocales] Error saving contact: $e');
          // Continue with next contact
        }
      }
      debugPrint(
          '[guardarContactosLocales] ✅ Saved ${contactos.length} contacts');
    } catch (e, stackTrace) {
      debugPrint('[guardarContactosLocales] Error: $e');
      debugPrint('[guardarContactosLocales] Stack trace: $stackTrace');
      // Don't throw - allow app to continue with local data
    }
  }

  Future<ChatMessage?> cargarArchivo({
    required List<File> result,
    required bool esGrupo,
    required incognito,
    required enviado,
    required recibido,
    animacion,
    required utc,
    String? para,
    Usuario? userPara,
    ChatMessage? messagetoReply,
    Grupo? grupoPara,
    bool? isforwarded,
    val,
  }) async {
    ChatMessage? newMessage;

    if (isforwarded != null) toggleBooleanValue(true);
    for (File file in result) {
      var fecha = deconstruirDateTime();
      // setState(() {
      //   _cargando = true;
      // });

      var exte = pathPKG.extension(file.path);
      exte = exte.toLowerCase();

      var type = 'default';

      var fileAsset = strtoFile(file.path);
      var fileEncode = await fileAsset.readAsBytes();

      if (exte == '.jpg' ||
          exte == '.png' ||
          exte == '.jpeg' ||
          exte == '.gif') {
        type = 'images';
        Uint8List? image =
            await FlutterImageCompress.compressWithFile(file.path, quality: 60);
        if (image != null) {
          var memoryImage = MemoryImage(image);
          fileEncode = memoryImage.bytes;
        }
      } else if (exte == '.mp4' ||
          exte == '.avi' ||
          exte == '.mov' ||
          exte == '.mkv') {
        type = 'video';
        // MediaInfo mediaInfo = await VideoCompress.compressVideo(
        //   file.path,
        //   quality: VideoQuality.LowQuality,
        //   deleteOrigin: false,
        // );
        // fileEncode = mediaInfo.file.readAsBytesSync();
        fileEncode = file.readAsBytesSync();
      } else if (exte == '.mp3' || exte == '.m4a') {
        type = 'audio';
      } else if (exte == '.aac') {
        type = 'recording';
      } else {
        type = 'documents';
      }

      var urlFile = '';
      urlFile = await saveFile(
          dataEncode: base64Encode(fileEncode), datafecha: fecha, exte: exte);
      var archivo = await MultipartFile.fromFile(urlFile);
      var newExte = type == 'recording' ? '$exte&$val' : exte;
      // CRITICAL: Prevent self-chat
      if (!esGrupo && usuario!.uid == userPara!.uid) {
        debugPrint('[AuthService] ⚠️ Cannot send file to self, ignoring');
        return null;
      }

      Dio dio = Dio();

      // DISAPPEARING MESSAGES: Get TTL for file uploads
      final prefs = await SharedPreferences.getInstance();
      final selectedDuration = prefs.getString('selectedDuration');
      final int? ttl = selectedDuration != null
          ? DurationHelper.getDurationInSeconds(selectedDuration)
          : null;

      var formData = FormData.fromMap({
        'de': usuario!.uid,
        'extension': newExte,
        'fecha': '${fecha}Z' + utc,
        'incognito': incognito,
        'para': esGrupo ? grupoPara!.codigo : userPara!.uid,
        'type': type,
        'file': archivo,
        'forwarded': isforwarded ?? false,
        'reply': messagetoReply != null,
        'parentType': messagetoReply?.type,
        'parentContent': messagetoReply?.texto,
        'parentSender':
            messagetoReply != null && messagetoReply.uid == usuario?.uid
                ? usuario?.nombre
                : para,
        'grupo': esGrupo ? grupoPara?.codigo : null,
        if (ttl != null) 'ttl': ttl, // DISAPPEARING: Send TTL to backend
      });

      _persistMessajeLocal(
        isforwarded: isforwarded,
        esGrupo: esGrupo,
        userPara: esGrupo ? null : userPara!,
        grupoPara: grupoPara,
        type: type,
        exte: newExte,
        content: urlFile,
        datefecha: fecha,
        incognito: incognito,
      );

      newMessage = ChatMessage(
        deleted: false,
        isReply: false,
        selected: false,
        dir: localPath!,
        uid: usuario!.uid!,
        texto: urlFile,
        forwarded: isforwarded ?? false,
        exten: newExte,
        incognito: incognito,
        enviado: enviado,
        recibido: recibido,
        hora: DateTime.now().toString(),
        type: type,
        fecha: fecha,
      );

      Mensaje mensajeLocal = Mensaje(deleted: false);
      mensajeLocal.mensaje = jsonEncode({
        'type': type,
        'content': urlFile,
        'fecha': fecha,
        'extension': exte
      });
      mensajeLocal.forwarded = isforwarded ?? false;
      mensajeLocal.de = usuario!.uid;
      mensajeLocal.para = esGrupo ? grupoPara!.codigo : userPara!.uid;
      mensajeLocal.createdAt = DateTime.now().toString();
      mensajeLocal.updatedAt = DateTime.now().toString();
      mensajeLocal.uid = esGrupo ? grupoPara!.codigo : userPara!.uid;

      // setState(() {
      //   _messages.insert(0, newMessage);
      //   newMessage.animationController.forward();
      // });

      String token = await AuthService.getToken();
      print('[UPLOAD] Uploading file (cargarArchivo): type=$type');
      print('[UPLOAD] URL: ${Environment.apiUrl}/archivos/subirArchivos');
      print('[UPLOAD] Token: YES (length: ${token.length})');

      var res = await dio.post(
        '${Environment.apiUrl}/archivos/subirArchivos',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          headers: {
            'x-token': token,
          },
          receiveTimeout: const Duration(minutes: 60),
          sendTimeout: const Duration(minutes: 60),
        ),
        onSendProgress: (int sent, int total) {
          var progress = sent / total;
          print('[UPLOAD] Progress: ${(progress * 100).toStringAsFixed(1)}%');
        },
      );

      print('[UPLOAD] Response status: ${res.statusCode}');
      print('[UPLOAD] Response data: ${res.data}');

      if (res.data['ok']) {
        print('[UPLOAD] ✅ Upload successful');
        var data = {
          'de': usuario!.uid,
          'para': esGrupo ? grupoPara!.codigo : userPara!.uid,
          'ext': newExte,
          'mensaje': {'content': urlFile, 'type': type, 'fecha': fecha},
          'forwarded': isforwarded != null ? true : false,
        };
        // DBProvider.db.actualizarEnviadoRecibido(data, 'enviado', true);
        DBProvider.db.messageSent(data, 'enviado', true);
        // DBProvider.db.actualizarEnviadoRecibido(data, 'enviado', true);
      }
    }
    if (isforwarded != null) toggleBooleanValue(false);
    return newMessage;
  }

  Future<Mensaje?> cargarArchivo1({
    required List<XFile> result,
    required bool esGrupo,
    required incognito,
    required enviado,
    required recibido,
    animacion,
    required utc,
    String? para,
    Usuario? userPara,
    ChatMessage? messagetoReply,
    Grupo? grupoPara,
    bool? isforwarded,
    val,
  }) async {
    Mensaje? newMessage;

    if (isforwarded != null) toggleBooleanValue(true);
    for (XFile file in result) {
      var fecha = deconstruirDateTime();
      // setState(() {
      //   _cargando = true;
      // });

      var exte = pathPKG.extension(file.path);
      exte = exte.toLowerCase();

      var type = 'default';

      var fileAsset = strtoFile(file.path);
      var fileEncode = await fileAsset.readAsBytes();

      if (exte == '.jpg' ||
          exte == '.png' ||
          exte == '.jpeg' ||
          exte == '.gif') {
        type = 'images';
        Uint8List? image =
            await FlutterImageCompress.compressWithFile(file.path, quality: 60);
        if (image != null) {
          var memoryImage = MemoryImage(image);
          fileEncode = memoryImage.bytes;
        }
      } else if (exte == '.mp4' ||
          exte == '.avi' ||
          exte == '.mov' ||
          exte == '.mkv') {
        type = 'video';
        /*     MediaInfo? mediaInfo = await VideoCompress.compressVideo(
          file.path,
          quality: VideoQuality.LowQuality,
          deleteOrigin: false,
        );
        fileEncode = mediaInfo!.file!.readAsBytesSync();
     */
        String path = await reduceSizeAndType(file.path);
        /* MediaInfo? mediaInfo = await VideoCompress.compressVideo(
        result,
        quality: VideoQuality.LowQuality,
        deleteOrigin: false,
      );
      var xxx =
      */
        fileEncode = File(path).readAsBytesSync();
      } else if (exte == '.mp3' || exte == '.m4a') {
        type = 'audio';
      } else if (exte == '.aac') {
        type = 'recording';
      } else {
        type = 'documents';
      }

      var urlFile = '';
      urlFile = await saveFile(
          dataEncode: base64Encode(fileEncode), datafecha: fecha, exte: exte);
      var newExte = type == 'recording' ? '$exte&$val' : exte;
      Dio dio = Dio();
      Response? res;
      _persistMessajeLocal(
        isforwarded: isforwarded,
        esGrupo: esGrupo,
        userPara: esGrupo ? null : userPara!,
        grupoPara: grupoPara,
        type: type,
        exte: newExte,
        content: urlFile,
        datefecha: fecha,
        incognito: incognito,
      );

      int maxRetries = 2;
      int retryCount = 0;
      bool shouldRetry = false;

      // DISAPPEARING MESSAGES: Get TTL for file uploads (outside retry loop)
      final prefs1 = await SharedPreferences.getInstance();
      final selectedDuration1 = prefs1.getString('selectedDuration');
      final int? ttl1 = selectedDuration1 != null
          ? DurationHelper.getDurationInSeconds(selectedDuration1)
          : null;

      do {
        shouldRetry = false;
        try {
          // Recreate FormData and MultipartFile for each retry attempt
          // (FormData cannot be reused once finalized)
          var retryArchivo = await MultipartFile.fromFile(urlFile);
          var formData = FormData.fromMap({
            'de': usuario!.uid,
            'extension': newExte,
            'fecha': '${fecha}Z' + utc,
            'incognito': incognito,
            'para': esGrupo ? grupoPara!.codigo : userPara!.uid,
            'type': type,
            'file': retryArchivo,
            'forwarded': isforwarded ?? false,
            'reply': messagetoReply != null,
            'parentType': messagetoReply?.type,
            'parentContent': messagetoReply?.texto,
            'parentSender':
                messagetoReply != null && messagetoReply.uid == usuario?.uid
                    ? usuario?.nombre
                    : para,
            'grupo': esGrupo ? grupoPara?.codigo : null,
            if (ttl1 != null) 'ttl': ttl1, // DISAPPEARING: Send TTL to backend
          });

          String token = await AuthService.getToken();
          if (retryCount > 0) {
            print(
                '[UPLOAD] Retry attempt $retryCount/$maxRetries (cargarArchivo1)');
            await Future.delayed(const Duration(seconds: 2));
          } else {
            print(
                '[UPLOAD] Uploading file (cargarArchivo1): type=$type, extension=$exte');
            print('[UPLOAD] URL: ${Environment.apiUrl}/archivos/subirArchivos');
            print('[UPLOAD] Token: YES (length: ${token.length})');
          }

          res = await dio.post(
            '${Environment.apiUrl}/archivos/subirArchivos',
            data: formData,
            options: Options(
              contentType: 'multipart/form-data',
              headers: {
                'x-token': token,
              },
              receiveTimeout: const Duration(minutes: 10), // Increased timeout
              sendTimeout: const Duration(minutes: 10),
              validateStatus: (status) {
                // Accept all status codes
                return true;
              },
            ),
            onSendProgress: (int sent, int total) {
              // Upload progress tracking
              var progress = sent / total;
              if (retryCount == 0) {
                // Only log on first attempt
                print(
                    '[UPLOAD] Progress: ${(progress * 100).toStringAsFixed(1)}%');
              }
            },
          );
          print('[UPLOAD] Response status: ${res.statusCode}');
          print('[UPLOAD] Response data: ${res.data}');
          shouldRetry = false; // Success
        } on DioException catch (e) {
          print('[UPLOAD] ❌ DioException caught (cargarArchivo1)');
          print('[UPLOAD] Error message: ${e.message}');
          print('[UPLOAD] Error type: ${e.type}');
          print('[UPLOAD] Error request path: ${e.requestOptions.path}');

          // Check if we have a response even with the exception
          if (e.response != null) {
            print('[UPLOAD] Response exists despite exception!');
            print('[UPLOAD] Response status: ${e.response!.statusCode}');
            print('[UPLOAD] Response data: ${e.response!.data}');
            // Use the response if it exists
            res = e.response;
            shouldRetry = false;
          } else {
            print('[UPLOAD] No response in exception');

            // Check if retryable
            if (e.error != null) {
              print('[UPLOAD] Error object: ${e.error}');
              String errorStr = e.error.toString();

              if ((errorStr.contains('Connection closed') ||
                      errorStr.contains('connection closed') ||
                      e.type == DioExceptionType.unknown) &&
                  retryCount < maxRetries) {
                print('[UPLOAD] Connection closed error - will retry');
                shouldRetry = true;
                retryCount++;
              } else {
                shouldRetry = false;
              }
            } else {
              shouldRetry = false;
            }
          }

          // Only rethrow if we don't have a valid response and no more retries
          if (!shouldRetry &&
              (e.response == null || e.response!.statusCode! >= 400)) {
            rethrow;
          }
        } catch (onError, stackTrace) {
          print('[UPLOAD] ❌ Unexpected error: $onError');
          print('[UPLOAD] Error type: ${onError.runtimeType}');
          print('[UPLOAD] Stack trace: $stackTrace');
          // Error handled - rethrow to let caller handle
          rethrow;
        }
      } while (shouldRetry && retryCount <= maxRetries);

      newMessage = Mensaje(deleted: false);

      newMessage.mensaje = jsonEncode({
        'type': type,
        'content': urlFile,
        'fecha': fecha,
        'extension': exte
      });
      newMessage.forwarded = isforwarded ?? false;
      newMessage.de = usuario!.uid;
      newMessage.para = esGrupo ? grupoPara!.codigo : userPara!.uid;
      newMessage.createdAt = DateTime.now().toString();
      newMessage.updatedAt = DateTime.now().toString();
      newMessage.uid = esGrupo ? grupoPara!.codigo : userPara!.uid;

      if (res != null && res.data['ok']) {
        var data = {
          'de': usuario!.uid,
          'para': esGrupo ? grupoPara!.codigo : userPara!.uid,
          'ext': newExte,
          'mensaje': {'content': urlFile, 'type': type, 'fecha': fecha},
          'forwarded': isforwarded != null ? true : false,
        };
        // DBProvider.db.actualizarEnviadoRecibido(data, 'enviado', true);
        // newMessage.enviado = 1;
        DBProvider.db.messageSent(data, 'enviado', true);
        // DBProvider.db.actualizarEnviadoRecibido(data, 'enviado', true);
        newMessage.enviado = 1;
      }
    }
    if (isforwarded != null) toggleBooleanValue(false);
    return newMessage;
  }

  Future<Mensaje?> cargarArchivo2({
    required String result,
    required bool esGrupo,
    required incognito,
    required enviado,
    required recibido,
    animacion,
    required utc,
    String? para,
    Usuario? userPara,
    ChatMessage? messagetoReply,
    Grupo? grupoPara,
    bool? isforwarded,
    BuildContext? ctx,
    val,
  }) async {
    Mensaje? newMessage;
    String mifecha = deconstruirDateTime();

    if (isforwarded != null) toggleBooleanValue(true);

    var fecha = mifecha;
    // setState(() {
    //   _cargando = true;
    // });

    var exte = pathPKG.extension(result);
    exte = exte.toLowerCase();

    var type = 'default';

    var fileAsset = strtoFile(result);
    var fileEncode = await fileAsset.readAsBytes();
    if (exte == '.jpg' || exte == '.png' || exte == '.jpeg' || exte == '.gif') {
      type = 'images';
      Uint8List? image =
          await FlutterImageCompress.compressWithFile(result, quality: 60);
      if (image != null) {
        var memoryImage = MemoryImage(image);
        fileEncode = memoryImage.bytes;
      }
    } else if (exte == '.mp4' ||
        exte == '.avi' ||
        exte == '.mov' ||
        exte == '.mkv') {
      type = 'video';

      String path = await reduceSizeAndType(result);
      /* MediaInfo? mediaInfo = await VideoCompress.compressVideo(
        result,
        quality: VideoQuality.LowQuality,
        deleteOrigin: false,
      );
      var xxx =
      */
      fileEncode = File(path).readAsBytesSync();
    } else if (exte == '.mp3' || exte == '.m4a') {
      type = 'audio';
    } else if (exte == '.aac') {
      type = 'recording';
    } else {
      type = 'documents';
    }

    var urlFile = '';
    urlFile = await saveFile(
        dataEncode: base64Encode(fileEncode), datafecha: fecha, exte: exte);
    var newExte = type == 'recording' ? '$exte&$val' : exte;
    _persistMessajeLocal(
      isforwarded: isforwarded,
      esGrupo: esGrupo,
      userPara: esGrupo ? null : userPara!,
      grupoPara: grupoPara,
      type: type,
      exte: newExte,
      content: urlFile,
      datefecha: fecha,
      incognito: incognito,
    );
    Dio dio = Dio();
    dynamic chatProvider;
    if (esGrupo) {
      chatProvider = Provider.of<GroupChatProvider>(ctx!, listen: false);
    } else {
      chatProvider = Provider.of<ChatProvider>(ctx!, listen: false);
    }

    Response? res;
    int maxRetries = 2;
    int retryCount = 0;
    bool shouldRetry = false;

    // DISAPPEARING MESSAGES: Get TTL for file uploads (outside retry loop)
    final prefs2 = await SharedPreferences.getInstance();
    final selectedDuration2 = prefs2.getString('selectedDuration');
    final int? ttl2 = selectedDuration2 != null
        ? DurationHelper.getDurationInSeconds(selectedDuration2)
        : null;

    do {
      shouldRetry = false;
      try {
        // Recreate FormData and MultipartFile for each retry attempt
        // (FormData cannot be reused once finalized)
        var retryArchivo = await MultipartFile.fromFile(urlFile);
        var formData = FormData.fromMap({
          'de': usuario!.uid,
          'extension': newExte,
          'fecha': '${fecha}Z' + utc,
          'incognito': incognito,
          'para': esGrupo ? grupoPara!.codigo : userPara!.uid,
          'type': type,
          'file': retryArchivo,
          'forwarded': isforwarded ?? false,
          'reply': messagetoReply != null,
          'parentType': messagetoReply?.type,
          'parentContent': messagetoReply?.texto,
          'parentSender':
              messagetoReply != null && messagetoReply.uid == usuario?.uid
                  ? usuario?.nombre
                  : para,
          'grupo': esGrupo ? grupoPara?.codigo : null,
          if (ttl2 != null) 'ttl': ttl2, // DISAPPEARING: Send TTL to backend
        });

        String token = await AuthService.getToken();
        if (retryCount > 0) {
          print('[UPLOAD] Retry attempt $retryCount/$maxRetries');
          // Wait a bit before retrying
          await Future.delayed(const Duration(seconds: 2));
        } else {
          print('[UPLOAD] Uploading file: type=$type, extension=$exte');
          print('[UPLOAD] URL: ${Environment.apiUrl}/archivos/subirArchivos');
          print('[UPLOAD] Token: YES (length: ${token.length})');
        }

        res = await dio.post(
          '${Environment.apiUrl}/archivos/subirArchivos',
          data: formData,
          options: Options(
            contentType: 'multipart/form-data',
            headers: {
              'x-token': token,
            },
            followRedirects: false,
            receiveTimeout:
                const Duration(minutes: 10), // Increased to 10 minutes
            sendTimeout: const Duration(minutes: 10), // Increased to 10 minutes
            validateStatus: (status) {
              // Accept all status codes - we'll check them manually
              return true;
            },
          ),
          onSendProgress: (int sent, int total) {
            var valor = sent / total;
            chatProvider.updateUpload(urlFile, fecha, valor);
            if (retryCount == 0) {
              // Only log progress on first attempt
              print('[UPLOAD] Progress: ${(valor * 100).toStringAsFixed(1)}%');
            }
          },
        );
        print('[UPLOAD] Response status: ${res.statusCode}');
        print('[UPLOAD] Response data: ${res.data}');
        shouldRetry = false; // Success, no retry needed
      } on DioException catch (e) {
        print('[UPLOAD] ❌ DioException caught');
        print('[UPLOAD] Error message: ${e.message}');
        print('[UPLOAD] Error type: ${e.type}');
        print('[UPLOAD] Error request path: ${e.requestOptions.path}');

        // Check if we have a response even with the exception
        if (e.response != null) {
          print('[UPLOAD] Response exists despite exception!');
          print('[UPLOAD] Response status: ${e.response!.statusCode}');
          print('[UPLOAD] Response data: ${e.response!.data}');
          // Use the response if it exists, even if there was an exception
          res = e.response;
          shouldRetry = false; // We have a response, no retry needed
        } else {
          print('[UPLOAD] No response in exception');

          // Log additional error details
          if (e.error != null) {
            print('[UPLOAD] Error object: ${e.error}');
            String errorStr = e.error.toString();

            // Check if it's a connection closed error that might be retryable
            if (errorStr.contains('Connection closed') ||
                errorStr.contains('connection closed') ||
                e.type == DioExceptionType.unknown) {
              if (retryCount < maxRetries) {
                print('[UPLOAD] Connection closed error - will retry');
                shouldRetry = true;
                retryCount++;
                res = null;
              } else {
                print('[UPLOAD] Max retries reached, giving up');
                res = null;
                shouldRetry = false;
              }
            } else {
              res = null;
              shouldRetry = false;
            }
          } else {
            res = null;
            shouldRetry = false;
          }
        }

        // Log additional error details
        if (!shouldRetry) {
          print('[UPLOAD] Stack trace: ${e.stackTrace}');
        }
      } catch (e, stackTrace) {
        print('[UPLOAD] ❌ Unexpected error: $e');
        print('[UPLOAD] Error type: ${e.runtimeType}');
        print('[UPLOAD] Stack trace: $stackTrace');
        res = null;
        shouldRetry = false;
      }
    } while (shouldRetry && retryCount <= maxRetries);

    newMessage = Mensaje(deleted: false);
    newMessage.mensaje = jsonEncode(
        {'type': type, 'content': urlFile, 'fecha': fecha, 'extension': exte});
    newMessage.forwarded = isforwarded ?? false;
    newMessage.de = usuario!.uid;
    newMessage.para = esGrupo ? grupoPara!.codigo : userPara!.uid;
    newMessage.createdAt = DateTime.now().toString();
    newMessage.updatedAt = DateTime.now().toString();
    newMessage.uid = esGrupo ? grupoPara!.codigo : userPara!.uid;

    // Check response - be more lenient with status codes
    bool uploadSuccess = false;
    if (res != null) {
      print('[UPLOAD] Checking response...');
      print('[UPLOAD] Status code: ${res.statusCode}');
      print('[UPLOAD] Has data: ${res.data != null}');

      // Accept 2xx status codes as success
      final statusCode = res.statusCode;
      if (statusCode != null && statusCode >= 200 && statusCode < 300) {
        if (res.data != null) {
          print('[UPLOAD] Response data type: ${res.data.runtimeType}');
          print('[UPLOAD] Response data: ${res.data}');

          // Check if ok is true (could be bool or string "ok")
          if (res.data is Map) {
            uploadSuccess = res.data['ok'] == true || res.data['ok'] == 'ok';
          } else if (res.data == 'ok' || res.data == true) {
            uploadSuccess = true;
          }
        } else {
          // If status is 200-299 but no data, assume success
          print(
              '[UPLOAD] No response data, but status is 2xx - assuming success');
          uploadSuccess = true;
        }
      }
    }

    if (uploadSuccess) {
      print('[UPLOAD] ✅ Upload successful');

      // Extract filename from response for socket messaging
      String? uploadedFilename;
      if (res?.data != null &&
          res!.data['filenames'] != null &&
          res.data['filenames'] is List &&
          res.data['filenames'].isNotEmpty) {
        uploadedFilename =
            res.data['filenames'][0]; // Get first uploaded filename
        print(
            '[UPLOAD] 📄 Extracted filename from response: $uploadedFilename');
      }

      var data = {
        'de': usuario!.uid,
        'para': esGrupo ? grupoPara!.codigo : userPara!.uid,
        'ext': newExte,
        'mensaje': {'content': urlFile, 'type': type, 'fecha': fecha},
        'forwarded': isforwarded != null ? true : false,
      };
      DBProvider.db.messageSent(data, 'enviado', true);
      // DBProvider.db.actualizarEnviadoRecibido(data, 'enviado', true);
      newMessage.enviado = 1;

      // CRITICAL FIX: Send socket message for group file uploads
      if (esGrupo && grupoPara != null) {
        print('[UPLOAD] 📤 Sending group file message via socket...');
        try {
          // Get socket service instance
          final socketService = Provider.of<SocketService>(ctx, listen: false);

          // Use uploaded filename for content if available, otherwise fallback to urlFile
          final messageContent = uploadedFilename ?? urlFile;

          // Prepare socket message data
          var socketData = {
            'de': usuario!.uid,
            'para': grupoPara.codigo,
            'incognito': incognito,
            'forwarded': isforwarded != null ? true : false,
            'reply': messagetoReply != null,
            'parentType': messagetoReply?.parenttype,
            'parentContent': messagetoReply?.parentmessage,
            'parentSender':
                messagetoReply != null && messagetoReply.uid == usuario!.uid
                    ? usuario!.nombre
                    : null,
            'mensaje': {
              'type': type,
              'content': messageContent,
              'fecha': '${fecha}Z${DateTime.now().timeZoneName}',
              'extension': exte
            },
            'usuario': {
              'nombre': usuario!.nombre,
            },
          };

          // Send via socket
          final emitResult =
              socketService.emitAck('mensaje-grupal', socketData);
          emitResult.then((ack) {
            if (ack != null && ack == "RECIBIDO_SERVIDOR") {
              print('[UPLOAD] ✅ Group file message socket ACK received: $ack');
            } else {
              print('[UPLOAD] ❌ Group file message socket failed - ACK: $ack');
            }
          }).catchError((error) {
            print('[UPLOAD] ❌ Group file message socket error: $error');
          });
        } catch (e) {
          print('[UPLOAD] ❌ Error sending group file socket message: $e');
        }
      }
    } else {
      print('[UPLOAD] ❌ Upload failed or response not OK');
      print('[UPLOAD] res is null: ${res == null}');
      if (res != null) {
        print('[UPLOAD] Status: ${res.statusCode}');
        if (res.data != null) {
          print('[UPLOAD] res.data: ${res.data}');
        }
      }
      newMessage.enviado = 0; // Mark as not sent
    }

    if (isforwarded != null) toggleBooleanValue(false);

    return newMessage;
  }

  saveFile({
    exte,
    dataEncode,
    datafecha,
  }) async {
    final decodedBytes = base64Decode(dataEncode);
    String dir = (await getApplicationDocumentsDirectory()).path;

    File file = File("$dir/" + datafecha + exte);
    await file.writeAsBytes(decodedBytes);
    return file.path;
  }

  _persistMessajeLocal({
    esGrupo,
    Usuario? userPara,
    Grupo? grupoPara,
    type,
    content,
    datefecha,
    exte,
    bool? isforwarded,
    incognito,
  }) {
    // CRITICAL: Prevent self-chat
    if (!esGrupo && usuario!.uid == userPara!.uid) {
      debugPrint('[AuthService] ⚠️ Cannot persist message to self, ignoring');
      return;
    }

    if (!incognito) {
      var fechaActual = formatDate(DateTime.parse(DateTime.now().toString()),
          [yyyy, '-', mm, '-', dd, ' ', HH, ':', nn, ':', ss]);
      Mensaje mensajeLocal = Mensaje(deleted: false);
      mensajeLocal.mensaje = jsonEncode({
        'type': type,
        'content': content,
        'fecha': datefecha,
        'extension': exte
      });
      mensajeLocal.forwarded = isforwarded ?? false;
      mensajeLocal.de = usuario!.uid;
      mensajeLocal.para = esGrupo ? grupoPara!.codigo : userPara!.uid;
      mensajeLocal.createdAt = fechaActual;
      mensajeLocal.updatedAt = fechaActual;
      mensajeLocal.uid = esGrupo ? grupoPara!.codigo : userPara!.uid;
      DBProvider.db.nuevoMensaje(mensajeLocal);
    }
    if (esGrupo) {
      Grupo grupoNuevo = Grupo();
      grupoNuevo.nombre = grupoPara!.nombre;
      grupoNuevo.avatar = grupoPara.avatar;
      grupoNuevo.codigo = grupoPara.codigo;
      grupoNuevo.descripcion = grupoPara.descripcion;
      grupoNuevo.fecha = grupoPara.fecha;
      grupoNuevo.usuarioCrea = grupoPara.usuarioCrea;
      grupoNuevo.publicKey = grupoPara.publicKey;
      grupoNuevo.privateKey = grupoPara.privateKey;
      DBProvider.db.nuevoGrupo(grupoNuevo);
    } else {
      // CRITICAL: Ensure contact UID is not current user
      if (userPara!.uid == usuario!.uid) {
        debugPrint('[AuthService] ⚠️ Cannot create contact with own UID');
        return;
      }

      Usuario contactoNuevo = Usuario(publicKey: userPara.publicKey);
      contactoNuevo.nombre = userPara.nombre;
      contactoNuevo.avatar = userPara.avatar;
      contactoNuevo.uid = userPara.uid;
      contactoNuevo.online = userPara.online;
      contactoNuevo.publicKey = userPara.publicKey;
      contactoNuevo.codigoContacto = userPara.codigoContacto;
      contactoNuevo.email = userPara.email;
      DBProvider.db.nuevoContacto(contactoNuevo);
    }
  }

  Future<String> reduceSizeAndType(String videoPath) async {
    assert(File(videoPath).existsSync());

    try {
      // Use video_compress for cross-platform video compression
      // LowQuality approximates the previous 720k bitrate target
      MediaInfo? mediaInfo = await VideoCompress.compressVideo(
        videoPath,
        quality: VideoQuality.LowQuality, // Closest to previous 720k bitrate
        deleteOrigin: false, // Keep original file
        includeAudio: true, // Keep audio (similar to -c:a copy in FFmpeg)
      );

      // Check if compression was successful and file exists
      if (mediaInfo?.path != null && File(mediaInfo!.path!).existsSync()) {
        return mediaInfo.path!;
      } else {
        // Fallback: return original if compression fails or returns null
        print(
            'Video compression returned null or file not found, using original file');
        return videoPath;
      }
    } catch (e) {
      // Error handling: return original file if compression fails
      // This ensures the app continues to work even if compression fails
      print('Video compression error: $e');
      return videoPath;
    }
  }
}
