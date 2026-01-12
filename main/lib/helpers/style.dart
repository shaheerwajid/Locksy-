import 'package:flutter/material.dart';

// Primary brand colors
Color primary = const Color(0xff1da1f2);
Color secondary = const Color(0xff5eb5f6);
Color colorSecondary =
    const Color.fromRGBO(49, 137, 173, 1); // Previously: amarillo
Color colorSecondaryLight =
    const Color.fromRGBO(49, 129, 173, 1); // Previously: amarilloClaro

// Surface and background colors
Color background = const Color(0xffF5F8FA);
Color colorSurface = const Color(0xffffffff); // Previously: full_white
Color colorSurfaceLight = const Color(0xfff7f8f3); // Previously: drawer_white
Color colorSurfaceLighter =
    const Color(0xffF0F0F0); // Previously: drawer_light_white
Color colorSurfaceLightest =
    const Color.fromRGBO(242, 241, 246, 1); // Previously: grisClaro

// Text colors
Color text_color = const Color(0xff14171A);
Color colorTextPrimary = const Color(0xff14171A); // Alias for text_color
Color colorTextSecondary = const Color.fromRGBO(117, 117, 117,
    1); // Previously: gris - Updated to #757575 for WCAG 4.5:1 contrast
Color colorTextOnPrimary = const Color(0xffFFFFFF); // Previously: icon_color

// Semantic colors
Color colorError = const Color.fromRGBO(250, 63, 56, 1); // Previously: rojo
Color colorSuccess = const Color.fromRGBO(133, 191, 63, 1); // Previously: verde
Color colorInfo = const Color.fromRGBO(41, 164, 219, 1); // Previously: azul
Color colorWarning =
    const Color.fromRGBO(49, 105, 173, 1); // Previously: naranja
Color colorAccent = const Color.fromRGBO(89, 44, 161, 1); // Previously: morado

// Chat-specific colors
Color chat_color = const Color(0xffebf5f7);
Color chat_color2 = const Color(0xffafd8de);
Color chat_send_color = const Color(0xffc5e4fd);
Color chat_receive_color = const Color(0xff9ed1fb);
Color chat_home_color = const Color(0xffecf6ff);

// UI element colors
Color white = const Color(0xffc5e4fd);
Color header = const Color(0xff5eb5f6);
Color sub_header = const Color(0xff75bff8);
Color icon_color = const Color(0xffFFFFFF);

// Legacy color names (deprecated - use semantic names above)
// Kept for backward compatibility during migration
@Deprecated('Use colorSecondary instead')
Color amarillo = colorSecondary;
@Deprecated('Use colorSecondaryLight instead')
Color amarilloClaro = colorSecondaryLight;
@Deprecated('Use colorSurface instead')
Color blanco = colorSurface;
@Deprecated('Use colorTextPrimary or Colors.black instead')
Color negro = const Color.fromRGBO(0, 0, 0, 1);
@Deprecated('Use colorSuccess instead')
Color verde = colorSuccess;
@Deprecated('Use colorTextSecondary instead')
Color gris = colorTextSecondary;
@Deprecated('Use colorSurfaceLightest instead')
Color grisClaro = colorSurfaceLightest;
@Deprecated('Use colorError instead')
Color rojo = colorError;
@Deprecated('Use colorInfo instead')
Color azul = colorInfo;
Color azulOscuro = const Color.fromRGBO(22, 122, 254, 1);
@Deprecated('Use colorAccent instead')
Color morado = colorAccent;
Color azulClaro = const Color.fromRGBO(80, 140, 212, 1);
Color naranja = colorWarning;
Color full_white = colorSurface;
Color drawer_white = colorSurfaceLight;
Color drawer_light_white = colorSurfaceLighter;

Color transparente = Colors.transparent;

//
ButtonStyle crearBotonStyle(Color? backgroundColor, Color? foregroundColor) {
  // backgroundColor kept for API compatibility
  final fgColor = foregroundColor ?? colorSurface;

  ButtonStyle raisedButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: fgColor,
    // primary: bgColor,
    minimumSize: const Size(80, 40),
    padding: const EdgeInsets.only(top: 10, bottom: 10),
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(5))),
  );
  return raisedButtonStyle;
}

//
/*
padding: EdgeInsets.only(top: 10, bottom: 10),
            color: azul,
            splashColor: blanco,
            child: Text(
                AppLocalizations.of(context).translate('ACTIVATE_NINJA_MODE'),
                style: TextStyle(
                  fontSize: 18,
                  color: blanco,
                ))
*/
