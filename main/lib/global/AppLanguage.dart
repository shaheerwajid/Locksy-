
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLanguage extends ChangeNotifier {
  late Locale _appLocale = const Locale("en"); // Default to English

  Locale get appLocal => _appLocale;

  Future<void> fetchLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString('language_code') ?? "en";
    _appLocale = Locale(languageCode);
  }

  Future<void> changeLanguage(String locale) async {
    final prefs = await SharedPreferences.getInstance();
    if (_appLocale.languageCode == locale) return;

    _appLocale = Locale(locale);
    await prefs.setString('language_code', locale);

    notifyListeners(); // Notify to rebuild the app with the new locale
  }
}
