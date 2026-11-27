import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

import '../../core/errors.dart';
import '../../core/languages.dart';

/// Engine-agnostic translation contract. UI never talks to an engine directly.
abstract class TranslationProvider {
  String get id;
  Future<bool> isReady(AppLang source, AppLang target);
  Future<String> translate(String text, AppLang source, AppLang target);
  Future<void> dispose();
}

TranslateLanguage mlkitLang(AppLang l) => switch (l) {
      AppLang.ar => TranslateLanguage.arabic,
      AppLang.de => TranslateLanguage.german,
    };

/// Google ML Kit on-device translation. Fully offline once the language
/// models (incl. English pivot) are downloaded. It never downloads on its own:
/// downloads happen only from the model manager with user consent.
class MlKitTranslationProvider implements TranslationProvider {
  final _manager = OnDeviceTranslatorModelManager();
  final _cache = <String, OnDeviceTranslator>{};

  @override
  String get id => 'mlkit-ondevice';

  @override
  Future<bool> isReady(AppLang s, AppLang t) async {
    for (final code in {mlkitLang(s).bcpCode, mlkitLang(t).bcpCode, 'en'}) {
      if (!await _manager.isModelDownloaded(code)) return false;
    }
    return true;
  }

  @override
  Future<String> translate(String text, AppLang s, AppLang t) async {
    if (text.trim().isEmpty) return '';
    if (!await isReady(s, t)) throw const ModelMissingFailure('mlkit');
    final key = '${s.code}-${t.code}';
    final tr = _cache[key] ??= OnDeviceTranslator(
        sourceLanguage: mlkitLang(s), targetLanguage: mlkitLang(t));
    try {
      return (await tr.translateText(text.trim())).trim();
    } catch (e) {
      throw AppFailure('err_translate', e);
    }
  }

  @override
  Future<void> dispose() async {
    for (final t in _cache.values) {
      await t.close();
    }
    _cache.clear();
  }
}

final translationProvider = Provider<TranslationProvider>((ref) {
  final p = MlKitTranslationProvider();
  ref.onDispose(p.dispose);
  return p;
});
