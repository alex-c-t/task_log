import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesProvider with ChangeNotifier {
  static const String _proModeKey = 'is_pro_mode';
  bool _isProMode = false;

  bool get isProMode => _isProMode;

  PreferencesProvider() {
    _loadFromPrefs();
  }

  void toggleProMode(bool value) async {
    _isProMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_proModeKey, _isProMode);
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _isProMode = prefs.getBool(_proModeKey) ?? false;
    notifyListeners();
  }
}
