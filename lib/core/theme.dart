import 'package:flutter/material.dart';

ThemeData buildTheme(Brightness b, {required bool highContrast}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF0B6E99),
    brightness: b,
    contrastLevel: highContrast ? 1.0 : 0.0,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    visualDensity: VisualDensity.standard,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 56),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
    ),
  );
}
