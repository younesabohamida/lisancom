import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

import '../../core/audio_utils.dart';
import '../../core/errors.dart';
import '../../core/languages.dart';
import '../model_manager/model_service.dart';
import 'speech_recognizer.dart';
import 'whisper_text_filter.dart';
import 'whisper_worker.dart';

/// Offline speech recognition: microphone PCM16 (with platform AEC / noise
/// suppression / AGC) -> in-memory buffer -> Whisper (sherpa-onnx) on device.
/// Audio is never written to disk.
class WhisperSpeechRecognizer implements SpeechRecognizer {
  WhisperSpeechRecognizer(this._loadFiles, this._worker);

  static const sampleRate = 16000;
  static const maxSeconds = 30; // Whisper window

  final Future<WhisperFiles?> Function() _loadFiles;
  final WhisperWorker _worker;
  final _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _sub;
  final _chunks = <Float32List>[];
  var _samples = 0;
  AppLang? _lang;
  WhisperFiles? _files;
  bool _autoStopFired = false;

  @override
  bool get supportsPartials => false;

  @override
  Future<void> start(
    AppLang lang, {
    void Function(String text)? onPartial,
    void Function(double level)? onLevel,
    void Function()? onAutoStop,
  }) async {
    _files = await _loadFiles();
    if (_files == null) throw const ModelMissingFailure('whisper');
    if (!await _recorder.hasPermission()) throw const AppFailure('err_mic_denied');
    _chunks.clear();
    _samples = 0;
    _lang = lang;
    _autoStopFired = false;
    final stream = await _recorder.startStream(const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: sampleRate,
      numChannels: 1,
      echoCancel: true,
      noiseSuppress: true,
      autoGain: true,
    ));
    _sub = stream.listen((bytes) {
      final f = pcm16ToFloat32(bytes);
      if (_samples >= maxSeconds * sampleRate) return;
      _chunks.add(f);
      _samples += f.length;
      onLevel?.call((rms(f) * 8).clamp(0.0, 1.0));
      if (_samples >= maxSeconds * sampleRate && !_autoStopFired) {
        _autoStopFired = true;
        onAutoStop?.call();
      }
    });
  }

  Future<Float32List> _finishCapture() async {
    try {
      await _recorder.stop();
    } catch (_) {}
    await _sub?.cancel();
    _sub = null;
    final all = concat(_chunks);
    _chunks.clear();
    return all;
  }

  @override
  Future<String> stop() async {
    final audio = await _finishCapture();
    // Too short or near-silent: don't run Whisper (prevents hallucinations).
    if (audio.length < sampleRate * 0.4 || rms(audio) < 0.004) return '';
    final text = await _worker.transcribe(
        files: _files!, lang: _lang!.whisper, samples: audio);
    return cleanWhisperText(text);
  }

  @override
  Future<void> cancel() async {
    await _finishCapture();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _recorder.dispose();
  }
}
