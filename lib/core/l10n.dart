import 'package:flutter/widgets.dart';

import 'l10n_strings.dart';

/// Lightweight, codegen-free localization. All UI text lives in
/// [l10nStrings]; a unit test enforces identical keys for every language.
class S {
  S(this.lang);
  final String lang;

  static const supported = [Locale('ar'), Locale('de')];
  static const fallback = Locale('de');

  static S of(BuildContext context) =>
      Localizations.of<S>(context, S) ?? S(fallback.languageCode);

  String t(String key, [Map<String, String> args = const {}]) {
    var s = l10nStrings[lang]?[key] ?? l10nStrings['de']![key] ?? key;
    args.forEach((k, v) => s = s.replaceAll('{$k}', v));
    return s;
  }
}

class SDelegate extends LocalizationsDelegate<S> {
  const SDelegate();
  @override
  bool isSupported(Locale l) => l10nStrings.containsKey(l.languageCode);
  @override
  Future<S> load(Locale l) async => S(l.languageCode);
  @override
  bool shouldReload(SDelegate old) => false;
}

extension TrX on BuildContext {
  String tr(String key, [Map<String, String> args = const {}]) =>
      S.of(this).t(key, args);
}
