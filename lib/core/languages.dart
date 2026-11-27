import 'package:flutter/widgets.dart';

/// Supported conversation languages. Adding a language = adding an enum value
/// and its codes here; engines read everything from this table.
enum AppLang {
  ar(code: 'ar', whisper: 'ar', sttLocale: 'ar-SA', ttsPrefix: 'ar',
      nativeName: 'العربية', rtl: true),
  de(code: 'de', whisper: 'de', sttLocale: 'de-DE', ttsPrefix: 'de',
      nativeName: 'Deutsch', rtl: false);

  const AppLang({
    required this.code,
    required this.whisper,
    required this.sttLocale,
    required this.ttsPrefix,
    required this.nativeName,
    required this.rtl,
  });

  final String code;
  final String whisper;
  final String sttLocale;
  final String ttsPrefix;
  final String nativeName;
  final bool rtl;

  TextDirection get direction => rtl ? TextDirection.rtl : TextDirection.ltr;

  /// Default partner language for the current AR<->DE product scope.
  AppLang get other => this == AppLang.ar ? AppLang.de : AppLang.ar;

  static AppLang fromCode(String c) =>
      AppLang.values.firstWhere((l) => l.code == c, orElse: () => AppLang.de);
}
