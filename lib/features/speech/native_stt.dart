import 'dart:async';

import 'package:speech_to_text/speech_to_text.dart';

import '../../core/errors.dart';
import '../../core/languages.dart';
import 'speech_recognizer.dart';

/// Platform speech recognition (Android SpeechRecognizer / iOS SFSpeech).
/// With [onDevice] = true it refuses to use the network; languages without an
/// installed offline pack then fail with a clear message instead of silently
/// sending audio to the cloud.
class NativeSpeechRecognizer implements SpeechRecognizer {
  NativeSpeechRecognizer({required this.onDevice});

  final bool onDevice;
  final _stt = SpeechToText();
  bool _initialized = false;
  String _last = '';
  String? _errorKey;
  Completer<String>? _final;
  void Function()? _onAutoStop;
  bool _stopping = false;

  @override
  bool get supportsPartials => true;

  void _complete() {
    if (_final != null && !_final!.isCompleted) _final!.complete(_last);
  }

  @override
  Future<void> start(
    AppLang lang, {
    void Function(String text)? onPartial,
    void Function(double level)? onLevel,
    void Function()? onAutoStop,
  }) async {
    if (!_initialized) {
      _initialized = await _stt.initialize(
        onError: (e) {
          final m = e.errorMsg.toLowerCase();
          _errorKey = m.contains('language') || m.contains('network')
              ? 'err_stt_native_unavailable'
              : (m.contains('no_match') || m.contains('speech_timeout'))
                  ? 'err_nothing_heard'
                  : 'err_stt';
          _complete();
          if (!_stopping) _onAutoStop?.call();
        },
        onStatus: (s) {
          if ((s == 'done' || s == 'notListening') && !_stopping) {
            _onAutoStop?.call();
          }
          if (s == 'done') _complete();
        },
      );
      if (!_initialized) throw const AppFailure('err_mic_denied');
    }
    final locales = await _stt.locales();
    final match = locales.where((l) =>
        l.localeId.toLowerCase().replaceAll('_', '-').startsWith(lang.code));
    if (match.isEmpty) {
      throw AppFailure(onDevice ? 'err_stt_native_unavailable' : 'err_stt');
    }
    final preferred = match.firstWhere(
        (l) => l.localeId.replaceAll('_', '-') == lang.sttLocale,
        orElse: () => match.first);
    _last = '';
    _errorKey = null;
    _stopping = false;
    _onAutoStop = onAutoStop;
    _final = Completer<String>();
    await _stt.listen(
      localeId: preferred.localeId,
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 4),
      onResult: (r) {
        _last = r.recognizedWords;
        onPartial?.call(_last);
        if (r.finalResult) _complete();
      },
      onSoundLevelChange: (l) => onLevel?.call(((l + 2) / 12).clamp(0.0, 1.0)),
      listenOptions: SpeechListenOptions(
        partialResults: true,
        onDevice: onDevice,
        listenMode: ListenMode.dictation,
        cancelOnError: true,
      ),
    );
  }

  @override
  Future<String> stop() async {
    _stopping = true;
    await _stt.stop();
    final text = await (_final?.future ?? Future.value(_last))
        .timeout(const Duration(seconds: 3), onTimeout: () => _last);
    if (text.trim().isEmpty && _errorKey != null && _errorKey != 'err_nothing_heard') {
      throw AppFailure(_errorKey!);
    }
    return text.trim();
  }

  @override
  Future<void> cancel() async {
    _stopping = true;
    await _stt.cancel();
    _complete();
  }

  @override
  void dispose() {
    _stt.cancel();
  }
}
