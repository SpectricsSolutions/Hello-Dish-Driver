import 'package:flutter/material.dart';

ThemeData light = ThemeData(
  fontFamily: 'Roboto',
  primaryColor: const Color(0xFFdb1d1d),
  secondaryHeaderColor: const Color(0xFFdb1d1d),
  disabledColor: const Color(0xFFA0A4A8),
  brightness: Brightness.light,
  hintColor: const Color(0xFF9F9F9F),
  cardColor: Colors.white,
  shadowColor: Colors.black.withValues(alpha: 0.03),
  scaffoldBackgroundColor: const Color(0xFFFCFCFC),

  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: const Color(0xFFdb1d1d),
    ),
  ),

  colorScheme: const ColorScheme.light(
    primary: Color(0xFFdb1d1d),
    secondary: Color(0xFFdb1d1d),
  ).copyWith(
    error: const Color(0xFFdb1d1d),
  ),

  popupMenuTheme: const PopupMenuThemeData(
    color: Colors.white,
    surfaceTintColor: Colors.white,
  ),

  dialogTheme: const DialogThemeData(
    surfaceTintColor: Colors.white,
  ),

  floatingActionButtonTheme: FloatingActionButtonThemeData(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(500),
    ),
  ),

  // ✅ FIXED — must use BottomAppBarThemeData
  bottomAppBarTheme: const BottomAppBarThemeData(
    color: Colors.black,
    height: 60,
    padding: EdgeInsets.symmetric(vertical: 5),
  ),

  dividerTheme: const DividerThemeData(
    thickness: 0.2,
    color: Color(0xFFA0A4A8),
  ),
);
