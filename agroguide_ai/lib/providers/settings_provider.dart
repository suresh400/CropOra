import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_service.dart';

class SettingsProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  Locale _locale = const Locale('en');
  bool _offlineMode = false;

  ThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;
  bool get offlineMode => _offlineMode;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('isDark') ?? false;
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    
    final langCode = prefs.getString('langCode') ?? 'en';
    _locale = Locale(langCode);
    
    _offlineMode = prefs.getBool('offlineMode') ?? false;

    notifyListeners();
  }

  Future<void> toggleTheme(bool isDark) async {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDark', isDark);
    
    final userId = prefs.getInt('mysql_user_id');
    if (userId != null) {
       await DatabaseService().saveSettings(userId, isDark ? 'dark' : 'light', _locale.languageCode, _offlineMode);
    }
    
    notifyListeners();
  }

  Future<void> setLanguage(String langCode) async {
    _locale = Locale(langCode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('langCode', langCode);
    
    final userId = prefs.getInt('mysql_user_id');
    if (userId != null) {
       await DatabaseService().saveSettings(userId, _themeMode == ThemeMode.dark ? 'dark' : 'light', langCode, _offlineMode);
    }
    
    notifyListeners();
  }

  Future<void> toggleOfflineMode(bool isOffline) async {
    _offlineMode = isOffline;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('offlineMode', isOffline);
    
    final userId = prefs.getInt('mysql_user_id');
    if (userId != null) {
       await DatabaseService().saveSettings(userId, _themeMode == ThemeMode.dark ? 'dark' : 'light', _locale.languageCode, isOffline);
    }
    
    notifyListeners();
  }
}
