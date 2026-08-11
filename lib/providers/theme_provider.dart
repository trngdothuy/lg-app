import 'package:flutter/material.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDark = false;
  bool get isDark => _isDark;

  void toggleDark() {
    _isDark = !_isDark;
    notifyListeners();
  }

  void setDark(bool value) {
    _isDark = value;
    notifyListeners();
  }
}