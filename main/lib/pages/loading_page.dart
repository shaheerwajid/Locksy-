// import 'dart:async';
//
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:rive/rive.dart' as rive;
// import 'package:CryptoChat/helpers/style.dart';
//
// import 'package:provider/provider.dart';
//
// import 'package:CryptoChat/services/socket_service.dart';
// import 'package:CryptoChat/services/auth_service.dart';
//
// import '../providers/db_provider.dart';
//
// class LoadingPage extends StatefulWidget {
//   @override
//   _LoadingPageState createState() => _LoadingPageState();
// }
//
// class _LoadingPageState extends State<LoadingPage> {
//   var periodic;
//   SocketService? socketService;
//
//   rive.Artboard? _riveArtboard;
//   rive.RiveAnimationController? controller;
//
//   @override
//   void initState() {
//     rootBundle.load('assets/rive/logo.riv').then(
//       (data) async {
//         await rive.RiveFile.initialize();
//         final file = rive.RiveFile.import(data);
//         final artboard = file.mainArtboard;
//         artboard.addController(controller = rive.SimpleAnimation('intro'));
//         setState(() => _riveArtboard = artboard);
//       },
//     );
//
//     socketService = Provider.of<SocketService>(context, listen: false);
//
//     DBProvider.db.database;
//     super.initState();
//   }
//
//   @override
//   void dispose() {
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: amarillo,
//       body: FutureBuilder(
//         future: checkLoginState(context),
//         builder: (context, snapshot) {
//           return Center(
//               child: Container(
//             // color: amarillo,
//             decoration: BoxDecoration(
//               gradient: LinearGradient(
//                 begin: Alignment.topCenter,
//                 end: Alignment.bottomCenter,
//                 colors: [
//                   amarillo,
//                   naranja,
//                 ],
//               ),
//             ),
//             child: _riveArtboard == null
//                 ? Container(
//                     height: MediaQuery.of(context).size.height,
//                     width: MediaQuery.of(context).size.width,
//                     child: Row(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         Icon(
//                           Icons.title,
//                           size: 100,
//                           color: blanco,
//                         ),
//                         Icon(
//                           Icons.bolt,
//                           size: 100,
//                           color: blanco,
//                         ),
//                       ],
//                     ))
//                 : rive.Rive(artboard: _riveArtboard!),
//           ));
//         },
//       ),
//     );
//   }
//
//   _verificaServidor() {
//     periodic = Timer.periodic(Duration(seconds: 6), (timer) {
//       if (socketService!.serverStatus == ServerStatus.Connecting ||
//           socketService!.serverStatus == ServerStatus.Offline) {
//         socketService!.canConnect();
//       } else {
//         try {
//           checkLoginState(context);
//         } catch (e) {}
//       }
//     });
//   }
//
//   Future checkLoginState(BuildContext context) async {
//     final authService = Provider.of<AuthService>(context, listen: false);
//     try {
//       final autenticado = await authService.isLoggedIn();
//
//       if (autenticado) {
//         socketService!.getKeys();
//
//         _verificaServidor();
//
//         socketService!.connect();
//
//         try {
//           Navigator.pushReplacementNamed(context, "home");
//         } catch (e) {
//           // print("HOME:> " + e.toString());
//         }
//       } else {
//         try {
//           Navigator.pushReplacementNamed(context, "login");
//         } catch (e) {
//           // print("LOGIN:> " + e.toString());
//         }
//       }
//       periodic.cancel();
//     } catch (e) {
//       // print("ERROR DATOS:> " + e.toString());
//     }
//   }
// }
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rive/rive.dart' as rive;
import 'package:CryptoChat/helpers/style.dart';
import 'package:provider/provider.dart';
import 'package:CryptoChat/services/socket_service.dart';
import 'package:CryptoChat/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/db_provider.dart';
import 'onboarding_screen.dart';

class LoadingPage extends StatefulWidget {
  const LoadingPage({super.key});

  @override
  _LoadingPageState createState() => _LoadingPageState();
}

class _LoadingPageState extends State<LoadingPage> {
  Timer? periodic;
  SocketService? socketService;

  rive.Artboard? _riveArtboard;
  rive.RiveAnimationController? controller;

  @override
  void initState() {
    super.initState();

    // Load Rive animation (with error handling)
    rootBundle.load('assets/rive/logo.riv').then(
      (data) async {
        try {
          await rive.RiveFile.initialize();
          final file = rive.RiveFile.import(data);
          final artboard = file.mainArtboard;
          artboard.addController(controller = rive.SimpleAnimation('intro'));
          if (mounted) {
            setState(() => _riveArtboard = artboard);
          }
        } catch (e) {
          print('Error loading Rive animation: $e');
          // Continue without animation
        }
      },
    ).catchError((error) {
      print('Error loading Rive file: $error');
      // Continue without animation
    });

    socketService = Provider.of<SocketService>(context, listen: false);

    // Initialize database (will be initialized when first accessed)
    // Don't await here to avoid blocking app startup
    DBProvider.db.database.then((db) {
      // Database initialized successfully
    }).catchError((error) {
      print('Error initializing database: $error');
      // Continue - database will be initialized when needed
    });

    _checkOnboardingStatus();
  }

  Future<void> _checkOnboardingStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool hasSeenOnboarding =
          prefs.getBool('hasSeenOnboarding') ?? false;

      // NINJA MODE CHECK: Check if app should start in calculator mode
      final String? initialRoute = prefs.getString('PMSInitialRoute');
      print('[LoadingPage] PMSInitialRoute: $initialRoute');
      print('[LoadingPage] hasSeenOnboarding: $hasSeenOnboarding');

      // If Ninja Mode is active (route is mainCalc), go straight to calculator
      if (initialRoute == 'mainCalc') {
        print('[LoadingPage] 🥷 Ninja Mode active - navigating to Calculator');
        if (mounted) {
          Navigator.pushReplacementNamed(context, 'mainCalc');
        }
        return;
      }

      if (hasSeenOnboarding) {
        // Proceed to check login state if onboarding is completed
        checkLoginState(context);
      } else {
        // Navigate to onboarding screen if not completed
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const OnboardingScreen()),
          );
        }
      }
    } catch (e) {
      print('[LoadingPage] Error checking onboarding status: $e');
      // On error, proceed to check login (assume onboarding was seen)
      checkLoginState(context);
    }
  }

  Future<void> checkLoginState(BuildContext context) async {
    final authService = Provider.of<AuthService>(context, listen: false);

    // CRITICAL: Retry logic for release builds
    // Storage access can fail on cold start due to Android Keystore timing issues
    const maxRetries = 2;
    bool? isAuthenticated;
    Exception? lastError;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print('[LoadingPage] Login check attempt $attempt/$maxRetries');
        isAuthenticated = await authService.isLoggedIn();
        print('[LoadingPage] isAuthenticated: $isAuthenticated');
        break; // Success
      } catch (e) {
        lastError = e as Exception;
        print('[LoadingPage] ⚠️ Error on attempt $attempt: $e');

        if (attempt < maxRetries) {
          print('[LoadingPage] Retrying after delay...');
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
    }

    // Cancel periodic timer
    if (periodic != null) {
      periodic!.cancel();
      periodic = null;
    }

    // Handle result
    if (isAuthenticated == true) {
      socketService!.getKeys();
      _verificaServidor();
      socketService!.connect();
      if (mounted) {
        Navigator.pushReplacementNamed(context, "home");
      }
    } else if (isAuthenticated == false) {
      // Explicitly not authenticated (token doesn't exist or is invalid)
      if (mounted) {
        Navigator.pushReplacementNamed(context, "login");
      }
    } else {
      // isAuthenticated is null - all attempts threw exceptions
      // CRITICAL: Don't silently redirect to login!
      // This could be a transient error, show error and let user retry
      print('[LoadingPage] ❌ All login check attempts failed: $lastError');
      if (mounted) {
        // For now, navigate to login, but log the error for debugging
        // In production, you might want to show an error dialog
        Navigator.pushReplacementNamed(context, "login");
      }
    }
  }

  @override
  void dispose() {
    // Cancel periodic timer if it exists
    if (periodic != null) {
      periodic!.cancel();
      periodic = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [background, background],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: _riveArtboard == null
              ? SizedBox(
                  height: MediaQuery.of(context).size.height,
                  width: MediaQuery.of(context).size.width,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.title, size: 100, color: text_color),
                      Icon(Icons.bolt, size: 100, color: text_color),
                    ],
                  ),
                )
              : rive.Rive(artboard: _riveArtboard!),
        ),
      ),
    );
  }

  _verificaServidor() {
    // Cancel existing timer if any
    if (periodic != null) {
      periodic!.cancel();
    }

    periodic = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (socketService!.serverStatus == ServerStatus.Connecting ||
          socketService!.serverStatus == ServerStatus.Offline) {
        socketService!.canConnect();
      } else {
        try {
          checkLoginState(context);
        } catch (e) {
          print('Error in _verificaServidor: $e');
        }
      }
    });
  }
}
