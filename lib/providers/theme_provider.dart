import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages the application's visual theme (Light/Dark).
///
/// Persists the user's preference to [SharedPreferences] key 'theme_mode'.
/// Defaults to [ThemeMode.system] if no preference is saved,
/// but defaults to Light for the first toggle.
class ThemeProvider with ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  static const String _colorKey = 'seed_color';
  
  ThemeMode _themeMode = ThemeMode.system;
  Color _seedColor = Colors.blue;

  ThemeMode get themeMode => _themeMode;
  Color get seedColor => _seedColor;

  ThemeProvider() {
    _loadFromPrefs();
  }

  void toggleTheme(bool isDark) async {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    _saveToPrefs();
  }

  void updateSeedColor(Color color) {
    _seedColor = color;
    notifyListeners();
    _saveToPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load theme
    final savedTheme = prefs.getString(_themeKey);
    if (savedTheme == 'dark') {
      _themeMode = ThemeMode.dark;
    } else if (savedTheme == 'light') {
      _themeMode = ThemeMode.light;
    } else {
      _themeMode = ThemeMode.system;
    }

    // Load color
    final savedColor = prefs.getInt(_colorKey);
    if (savedColor != null) {
      _seedColor = Color(savedColor);
    }
    
    notifyListeners();
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Save theme
    String themeValue;
    switch (_themeMode) {
      case ThemeMode.dark: themeValue = 'dark'; break;
      case ThemeMode.light: themeValue = 'light'; break;
      default: themeValue = 'system';
    }
    await prefs.setString(_themeKey, themeValue);

    // Save color
    await prefs.setInt(_colorKey, _seedColor.value);
  }
}
