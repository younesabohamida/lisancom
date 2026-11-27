import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../core/errors.dart';
import '../../core/languages.dart';

/// System TTS (Android TextToSpeech / iOS AVSpeechSynthesizer).
/// Works offline when the voice data for the language is installed.
class TtsService {
  final _tts = FlutterTts();
  bool _ready = false;
  final _resolved = <AppLang, String?>{};

  static const _preferred = {
    AppLang.ar: ['ar-SA', 'ar-EG', 'ar-XA', 'ar-AE', 'ar'],
    AppLang.de: ['de-DE', 'de-AT', 'de-CH', 'de'],
  };

  Future<void> _ensure() async {
    if (_ready) return;
    await _tts.awaitSpeakCompletion(true);
    if (Platform.isIOS) {
      await _tts.setSharedInstance(true);
      await _tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playAndRecord,
        [
          IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
        ],
        IosTextToSpeechAudioMode.defaultMode,
      );
    }
    _ready = true;
  }

  Future<String?> resolveLocale(AppLang l) async {
    if (_resolved.containsKey(l)) return _resolved[l];
    await _ensure();
    String? found;
    try {
      final langs = ((await _tts.getLanguages) as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[];
      final lower = {for (final x in langs) x.toLowerCase().replaceAll('_', '-'): x};
      for (final p in _preferred[l]!) {
        if (lower[p.toLowerCase()] != null) {
          found = lower[p.toLowerCase()];
          break;
        }
      }
      found ??= langs.cast<String?>().firstWhere(
          (x) => x!.toLowerCase().startsWith(l.ttsPrefix),
          orElse: () => null);
    } catch (_) {}
    // Only cache successful lookups, so installing a voice later is picked up.
    if (found != null) _resolved[l] = found;
    return found;
  }

  /// True when the voice can be used without network.
  Future<bool> isAvailableOffline(AppLang l) async {
    final loc = await resolveLocale(l);
    if (loc == null) return false;
    try {
      if (Platform.isAndroid) {
        return (await _tts.isLanguageInstalled(loc)) == true;
      }
      return (await _tts.isLanguageAvailable(loc)) == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> speak(String text, AppLang l, {double rate = 0.45}) async {
    if (text.trim().isEmpty) return;
    final loc = await resolveLocale(l);
    if (loc == null) throw const AppFailure('err_tts');
    try {
      await _tts.stop();
      await _tts.setLanguage(loc);
      await _tts.setSpeechRate(rate);
      await _tts.setVolume(1.0);
      await _tts.speak(text);
    } catch (e) {
      throw AppFailure('err_tts', e);
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }

  void forgetCache() => _resolved.clear();
}

final ttsProvider = Provider<TtsService>((ref) {
  final s = TtsService();
  ref.onDispose(s.stop);
  return s;
});
