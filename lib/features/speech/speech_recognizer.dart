import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/languages.dart';
import '../../core/settings.dart';
import '../model_manager/model_service.dart';
import 'native_stt.dart';
import 'whisper_stt.dart';
import 'whisper_worker.dart';

/// Engine-agnostic speech recognition contract (push-to-talk session).
abstract class SpeechRecognizer {
  /// Whether [start]'s onPartial delivers live text. Whisper is
  /// non-streaming (honest: it transcribes after you stop).
  bool get supportsPartials;

  Future<void> start(
    AppLang lang, {
    void Function(String text)? onPartial,
    void Function(double level)? onLevel,
    void Function()? onAutoStop,
  });

  /// Ends capture and returns the final transcript ('' if nothing heard).
  Future<String> stop();

  Future<void> cancel();

  void dispose();
}

final whisperWorkerProvider = Provider<WhisperWorker>((ref) {
  final w = WhisperWorker();
  ref.onDispose(w.dispose);
  return w;
});

final speechRecognizerProvider = Provider<SpeechRecognizer>((ref) {
  final cfg = ref.watch(settingsProvider
      .select((s) => (s.sttEngine, s.offlineOnly, s.whisperModelId)));
  final SpeechRecognizer r = cfg.$1 == SttEngine.whisper
      ? WhisperSpeechRecognizer(
          () => ref.read(modelServiceProvider.notifier).whisperFiles(cfg.$3),
          ref.read(whisperWorkerProvider),
        )
      : NativeSpeechRecognizer(onDevice: cfg.$2);
  ref.onDispose(r.dispose);
  return r;
});
