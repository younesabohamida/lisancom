import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../../core/errors.dart';
import '../model_manager/model_service.dart';

/// Long-lived background isolate that owns the sherpa-onnx Whisper
/// recognizer(s), so model loading and decoding never block the UI.
class WhisperWorker {
  Isolate? _isolate;
  SendPort? _tx;
  ReceivePort? _rx;
  Future<void>? _starting;
  final _pending = <int, Completer<String>>{};
  var _nextId = 0;

  Future<void> _start() async {
    final rx = _rx = ReceivePort();
    final ready = Completer<SendPort>();
    rx.listen((msg) {
      if (msg is SendPort) {
        ready.complete(msg);
      } else if (msg is Map) {
        final c = _pending.remove(msg['id']);
        if (msg['error'] != null) {
          c?.completeError(AppFailure('err_stt', msg['error']));
        } else {
          c?.complete(msg['text'] as String);
        }
      }
    });
    _isolate = await Isolate.spawn(_whisperEntry, rx.sendPort, debugName: 'whisper');
    _tx = await ready.future;
  }

  Future<String> transcribe({
    required WhisperFiles files,
    required String lang,
    required Float32List samples,
    int threads = 2,
  }) async {
    _starting ??= _start();
    await _starting;
    final id = ++_nextId;
    final c = _pending[id] = Completer<String>();
    _tx!.send({
      'id': id,
      'model': files.spec.id,
      'enc': files.encoder,
      'dec': files.decoder,
      'tok': files.tokens,
      'lang': lang,
      'threads': threads,
      'keepBoth': files.spec.keepBothLanguagesLoaded,
      'samples': TransferableTypedData.fromList([samples]),
    });
    return c.future;
  }

  void dispose() {
    _tx?.send('exit');
    _isolate?.kill(priority: Isolate.beforeNextEvent);
    _rx?.close();
    for (final c in _pending.values) {
      c.completeError(const AppFailure('err_stt', 'disposed'));
    }
    _pending.clear();
    _isolate = null;
    _tx = null;
    _starting = null;
  }
}

@pragma('vm:entry-point')
void _whisperEntry(SendPort out) {
  final inbox = ReceivePort();
  out.send(inbox.sendPort);
  sherpa.initBindings();
  final recs = <String, sherpa.OfflineRecognizer>{};

  void freeWhere(bool Function(String key) test) {
    recs.removeWhere((k, r) {
      if (!test(k)) return false;
      r.free();
      return true;
    });
  }

  inbox.listen((msg) {
    if (msg is! Map) {
      freeWhere((_) => true);
      inbox.close();
      return;
    }
    final id = msg['id'];
    try {
      final model = msg['model'] as String;
      final lang = msg['lang'] as String;
      final key = '$model|$lang';
      var rec = recs[key];
      if (rec == null) {
        // Free other models; keep the other language only if allowed (memory).
        freeWhere((k) => !k.startsWith('$model|') || !(msg['keepBoth'] as bool));
        rec = sherpa.OfflineRecognizer(sherpa.OfflineRecognizerConfig(
          model: sherpa.OfflineModelConfig(
            whisper: sherpa.OfflineWhisperModelConfig(
              encoder: msg['enc'] as String,
              decoder: msg['dec'] as String,
              language: lang,
              task: 'transcribe',
            ),
            tokens: msg['tok'] as String,
            modelType: 'whisper',
            numThreads: msg['threads'] as int,
            debug: false,
          ),
        ));
        recs[key] = rec;
      }
      final samples =
          (msg['samples'] as TransferableTypedData).materialize().asFloat32List();
      final stream = rec.createStream();
      stream.acceptWaveform(samples: samples, sampleRate: 16000);
      rec.decode(stream);
      final text = rec.getResult(stream).text;
      stream.free();
      out.send({'id': id, 'text': text.trim()});
    } catch (e) {
      out.send({'id': id, 'error': e.toString()});
    }
  });
}
