import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:CryptoChat/global/environment.dart';

class AppLocalizations {
  AppLocalizations(this.locale) : _localizedStrings = {};
  Locale locale;

  // Helper method to keep the code in the widgets concise
  // Localizations are accessed using an InheritedWidget "of" syntax
  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  Map<String, String> _localizedStrings;

  // Static member to have a simple access to the delegate from the MaterialApp
  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  Future<bool> load() async {
    // Load the language JSON file from the "lang" folder
    var prefs = await SharedPreferences.getInstance();
    var languageCode =
        prefs.getString("language_code") ?? "en"; // Default to 'en'
    var locale = Locale(languageCode);
    String jsonString =
        await rootBundle.loadString('lang/${locale.languageCode}.json');
    // await rootBundle.loadString('lang/${locale.languageCode}.json');
    Map<String, dynamic> jsonMap = json.decode(jsonString);

    _localizedStrings = jsonMap.map((key, value) {
      return MapEntry(key, value.toString());
    });

    return true;
  }

  // This method will be called from every widget which needs a localized text
  String translate(String key) {
    try {
      final value = _localizedStrings[key];
      if (value != null && value.isNotEmpty) {
        return value;
      }
      // Fallback: return the key itself if translation not found
      // This prevents crashes and helps identify missing translations
      debugPrint('[AppLocalizations] Translation key not found: $key');
      return key;
    } catch (e) {
      debugPrint('[AppLocalizations] Error translating key "$key": $e');
      return key;
    }
  }

  String translateReplace(String key, String replaceBy, String replaceTo) {
    final res = _localizedStrings[key];
    if (res == null) {
      // Fallback: if key not found, return a safe default
      // Optionally replace in the key itself if it contains the replace pattern
      debugPrint(
          '[AppLocalizations] Translation key not found for replace: $key');
      if (key.contains(replaceBy)) {
        return key.replaceAll(replaceBy, replaceTo);
      }
      return key;
    }
    return res.replaceAll(replaceBy, replaceTo);
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  // This delegate instance will never change (it doesn't even have fields!)
  // It can provide a constant constructor.
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    // Include all of your supported language codes here
    return Environment.locales.contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    // AppLocalizations class is where the JSON loading actually runs
    AppLocalizations localizations = AppLocalizations(locale);
    await localizations.load();
    return localizations;
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => true;
}
