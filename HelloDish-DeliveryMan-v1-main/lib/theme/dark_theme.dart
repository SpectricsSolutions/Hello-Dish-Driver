import 'package:flutter/material.dart';

ThemeData dark = ThemeData(
  fontFamily: 'Roboto',
  primaryColor: const Color(0xFFdb1d1d),
  secondaryHeaderColor: const Color(0xFFdb1d1d),
  disabledColor: const Color(0xFF6f7275),
  brightness: Brightness.dark,
  hintColor: const Color(0xFFbebebe),
  cardColor: Colors.black,
  shadowColor: Colors.white.withValues(alpha: 0.03),
  scaffoldBackgroundColor: const Color(0xFF161617),
  textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: const Color(0xFFdb1d1d))),
  colorScheme: const ColorScheme.dark(primary: Color(0xFFdb1d1d), secondary: Color(0xFFdb1d1d)).copyWith(error: const Color(0xFFdb1d1d)),
  popupMenuTheme: const PopupMenuThemeData(color: Color(0xFF29292D), surfaceTintColor: Color(0xFF29292D)),
  dialogTheme: const DialogThemeData(surfaceTintColor: Colors.white10),
  floatingActionButtonTheme: FloatingActionButtonThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(500))),
  bottomAppBarTheme: const BottomAppBarThemeData(
    color: Colors.black,
    height: 60,
    padding: EdgeInsets.symmetric(vertical: 5),
  ),

  dividerTheme: const DividerThemeData(thickness: 0.2, color: Color(0xFFA0A4A8)),
);