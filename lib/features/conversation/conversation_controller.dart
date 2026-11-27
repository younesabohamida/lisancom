import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors.dart';
import '../../core/languages.dart';
import '../../core/settings.dart';
import '../speech/speech_recognizer.dart';
import '../translation/critical_info_guard.dart';
import '../translation/translation_provider.dart';
import '../tts/tts_service.dart';

enum ConvPhase { idle, listening, recognizing, translating, speaking }

class ConvEntry {
  const ConvEntry(this.from, this.original, this.translated, this.guard);
  final AppLang from;
  final String original;
  final String translated;
  final GuardResult guard;
  AppLang get to => from.other;
}

class ConvState {
  const ConvState({
    this.phase = ConvPhase.idle,
    this.active,
    this.partial = '',
    this.level = 0,
    this.entries = const [],
    this.errorKey,
    this.infoKey,
  });

  final ConvPhase phase;
  final AppLang? active;
  final String partial;
  final double level;
  final List<ConvEntry> entries; // in memory only, never persisted
  final String? errorKey;
  final String? infoKey;

  bool get busy =>
      phase == ConvPhase.recognizing || phase == ConvPhase.translating;

  ConvState copyWith({
    ConvPhase? phase,
    AppLang? active,
    String? partial,
    double? level,
    List<ConvEntry>? entries,
    String? errorKey,
    String? infoKey,
    bool clearMessages = false,
  }) =>
      ConvState(
        phase: phase ?? this.phase,
        active: active ?? this.active,
        partial: partial ?? this.partial,
        level: level ?? this.level,
        entries: entries ?? this.entries,
        errorKey: clearMessages ? errorKey : (errorKey ?? this.errorKey),
        infoKey: clearMessages ? infoKey : (infoKey ?? this.infoKey),
      );
}

final conversationProvider =
    NotifierProvider<ConversationController, ConvState>(ConversationController.new);

/// Manual (push-to-talk) conversation pipeline:
/// mic -> STT -> translation -> critical-info check -> TTS.
/// Recording never overlaps playback, which prevents re-capturing the
/// translated speech from the loudspeaker.
class ConversationController extends Notifier<ConvState> {
  @override
  ConvState build() => const ConvState();

  SpeechRecognizer get _stt => ref.read(speechRecognizerProvider);
  TtsService get _tts => ref.read(ttsProvider);
  AppSettings get _settings => ref.read(settingsProvider);

  void _haptic() => _settings.seniorMode
      ? HapticFeedback.heavyImpact()
      : HapticFeedback.lightImpact();

  void _fail(Object e) {
    if (!ref.mounted) return;
    state = state.copyWith(
      phase: ConvPhase.idle,
      partial: '',
      level: 0,
      clearMessages: true,
      errorKey: e is AppFailure ? e.key : 'err_generic',
    );
  }

  Future<void> toggle(AppLang lang) async {
    switch (state.phase) {
      case ConvPhase.listening:
        if (state.active == lang) await finish();
        return;
      case ConvPhase.recognizing:
      case ConvPhase.translating:
        return;
      case ConvPhase.speaking:
        await _tts.stop();
      case ConvPhase.idle:
        break;
    }
    await _start(lang);
  }

  Future<void> _start(AppLang lang) async {
    await _tts.stop();
    _haptic();
    state = state.copyWith(
        phase: ConvPhase.listening, active: lang, partial: '', level: 0, clearMessages: true);
    try {
      await _stt.start(
        lang,
        onPartial: (t) {
          if (ref.mounted && state.phase == ConvPhase.listening) {
            state = state.copyWith(partial: t);
          }
        },
        onLevel: (l) {
          if (ref.mounted && state.phase == ConvPhase.listening) {
            state = state.copyWith(level: l);
          }
        },
        onAutoStop: () {
          if (ref.mounted && state.phase == ConvPhase.listening) {
            if (!_stt.supportsPartials) state = state.copyWith(infoKey: 'max_duration');
            finish();
          }
        },
      );
    } catch (e) {
      try {
        await _stt.cancel();
      } catch (_) {}
      _fail(e);
    }
  }

  Future<void> finish() async {
    if (state.phase != ConvPhase.listening) return;
    final from = state.active!;
    _haptic();
    state = state.copyWith(phase: ConvPhase.recognizing, level: 0);
    try {
      final text = await _stt.stop();
      if (!ref.mounted) return;
      if (text.isEmpty) {
        state = state.copyWith(
            phase: ConvPhase.idle, partial: '', clearMessages: true, errorKey: 'err_nothing_heard');
        return;
      }
      state = state.copyWith(phase: ConvPhase.translating, partial: text);
      final translated =
          await ref.read(translationProvider).translate(text, from, from.other);
      if (!ref.mounted) return;
      final entry =
          ConvEntry(from, text, translated, CriticalInfoGuard.check(text, translated));
      final speak = _settings.autoSpeak;
      state = state.copyWith(
        phase: speak ? ConvPhase.speaking : ConvPhase.idle,
        partial: '',
        entries: [...state.entries, entry],
      );
      if (speak) await _speak(entry);
    } catch (e) {
      _fail(e);
    }
  }

  Future<void> _speak(ConvEntry e) async {
    try {
      await _tts.speak(e.translated, e.to, rate: _settings.speechRate);
      if (ref.mounted && state.phase == ConvPhase.speaking) {
        state = state.copyWith(phase: ConvPhase.idle);
      }
    } catch (err) {
      _fail(err);
    }
  }

  Future<void> replay(ConvEntry e) async {
    if (state.phase != ConvPhase.idle && state.phase != ConvPhase.speaking) return;
    state = state.copyWith(phase: ConvPhase.speaking, clearMessages: true);
    await _speak(e);
  }

  Future<void> stopSpeaking() async {
    await _tts.stop();
    if (state.phase == ConvPhase.speaking) state = state.copyWith(phase: ConvPhase.idle);
  }

  void dismissMessage() => state = state.copyWith(clearMessages: true);

  Future<void> clear() async {
    await _tts.stop();
    state = const ConvState();
  }
}
