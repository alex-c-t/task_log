import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesProvider with ChangeNotifier {
  static const String _proModeKey = 'is_pro_mode';
  static const String _proPlanKey = 'is_pro_plan';
  
  bool _isProMode = false;
  bool _isProPlan = true;

  bool get isProMode => _isProMode;
  bool get isProPlan => _isProPlan;

  PreferencesProvider() {
    _loadFromPrefs();
  }

  void toggleProMode(bool value) async {
    // Only allow turning on Pro Mode if the user is on the Pro Plan
    if (!_isProPlan && value) return;
    
    _isProMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_proModeKey, _isProMode);
  }

  void updateProPlan(bool value) async {
    _isProPlan = value;
    // If they lose the pro plan, we must force them out of pro mode
    if (!_isProPlan) {
      _isProMode = false;
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_proPlanKey, _isProPlan);
    await prefs.setBool(_proModeKey, _isProMode);
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _isProPlan = prefs.getBool(_proPlanKey) ?? true;
    _isProMode = prefs.getBool(_proModeKey) ?? false;
    
    // Integrity check
    if (!_isProPlan && _isProMode) {
      _isProMode = false;
    }
    
    notifyListeners();
  }
}
