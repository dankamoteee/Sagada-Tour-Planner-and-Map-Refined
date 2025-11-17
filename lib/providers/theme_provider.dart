import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system; // Default to system theme
  ThemeMode get themeMode => _themeMode;

  ThemeProvider(SharedPreferences prefs) {
    // Load the saved theme from preferences when the provider is created
    final isDark = prefs.getBool('isDarkMode');
    if (isDark == null) {
      _themeMode = ThemeMode.system;
    } else {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    }
  }

  Future<void> setTheme(bool isDark) async {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;

    // Save the choice
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDark);

    // Notify all listeners to rebuild
    notifyListeners();
  }
}
