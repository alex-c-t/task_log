import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages the application's visual theme (Light/Dark).
///
/// Persists the user's preference to [SharedPreferences] key 'theme_mode'.
/// Defaults to [ThemeMode.system] if no preference is saved,
/// but defaults to Light for the first toggle.
class ThemeProvider with ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  ThemeProvider() {
    _loadTheme();
  }

  /// Toggles between Light and Dark mode.
  ///
  /// [isDark] - true for Dark Mode, false for Light Mode.
  void toggleTheme(bool isDark) async {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    _saveTheme(_themeMode);
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString(_themeKey);
    if (savedTheme == 'dark') {
      _themeMode = ThemeMode.dark;
    } else if (savedTheme == 'light') {
      _themeMode = ThemeMode.light;
    } else {
      _themeMode = ThemeMode.system;
    }
    notifyListeners();
  }

  Future<void> _saveTheme(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    String value;
    switch (mode) {
      case ThemeMode.dark:
        value = 'dark';
        break;
      case ThemeMode.light:
        value = 'light';
        break;
      default:
        value = 'system';
    }
    await prefs.setString(_themeKey, value);
  }
}
