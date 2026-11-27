import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/errors.dart';
import '../../core/languages.dart';
import '../../core/settings.dart';
import '../tts/tts_service.dart';
import 'downloader.dart';
import 'model_catalog.dart';

enum PackKind { translation, whisper, tts }

class PackState {
  const PackState({
    required this.id,
    required this.kind,
    this.installed = false,
    this.downloading = false,
    this.progress,
    this.hasPartial = false,
    this.errorKey,
    this.approxMB,
  });

  final String id;
  final PackKind kind;
  final bool installed;
  final bool downloading;
  final double? progress; // null while downloading = indeterminate
  final bool hasPartial;
  final String? errorKey;
  final int? approxMB;

  PackState copyWith({
    bool? installed,
    bool? downloading,
    double? progress,
    bool clearProgress = false,
    bool? hasPartial,
    String? errorKey,
    bool clearError = false,
  }) =>
      PackState(
        id: id,
        kind: kind,
        installed: installed ?? this.installed,
        downloading: downloading ?? this.downloading,
        progress: clearProgress ? null : (progress ?? this.progress),
        hasPartial: hasPartial ?? this.hasPartial,
        errorKey: clearError ? null : (errorKey ?? this.errorKey),
        approxMB: approxMB,
      );
}

class WhisperFiles {
  const WhisperFiles(this.spec, this.encoder, this.decoder, this.tokens);
  final WhisperModelSpec spec;
  final String encoder, decoder, tokens;
}

final catalogProvider = FutureProvider<ModelCatalog>((ref) async =>
    ModelCatalog.parse(await rootBundle.loadString('assets/models/catalog.json')));

String mlkitPackId(String code) => 'mlkit-$code';
String ttsPackId(AppLang l) => 'tts-${l.code}';

final modelServiceProvider =
    NotifierProvider<ModelService, Map<String, PackState>>(ModelService.new);

class ModelService extends Notifier<Map<String, PackState>> {
  final _mlkit = OnDeviceTranslatorModelManager();
  final _downloader = Downloader();
  final _cancels = <String, CancelToken>{};
  Directory? _root;

  static const mlkitCodes = ['ar', 'de', 'en'];

  @override
  Map<String, PackState> build() {
    Future.microtask(refresh);
    return {};
  }

  Future<Directory> _modelsRoot() async => _root ??= Directory(
      '${(await getApplicationSupportDirectory()).path}/models');

  Future<Directory> _dirOf(String id) async =>
      Directory('${(await _modelsRoot()).path}/$id');

  void _set(PackState s) => state = {...state, s.id: s};

  Future<void> refresh() async {
    final catalog = await ref.read(catalogProvider.future);
    final next = <String, PackState>{};
    for (final c in mlkitCodes) {
      bool ok = false;
      try {
        ok = await _mlkit.isModelDownloaded(c);
      } catch (_) {}
      next[mlkitPackId(c)] = PackState(
          id: mlkitPackId(c), kind: PackKind.translation, installed: ok, approxMB: 30);
    }
    for (final w in catalog.whisper) {
      final dir = await _dirOf(w.id);
      next[w.id] = PackState(
        id: w.id,
        kind: PackKind.whisper,
        installed: await _whisperInstalled(w),
        hasPartial: await dir.exists() &&
            await dir.list().any((e) => e.path.endsWith('.part')),
        approxMB: w.approxMB,
      );
    }
    final tts = ref.read(ttsProvider);
    tts.forgetCache();
    for (final l in AppLang.values) {
      next[ttsPackId(l)] = PackState(
          id: ttsPackId(l), kind: PackKind.tts, installed: await tts.isAvailableOffline(l));
    }
    // Keep in-flight download state.
    for (final e in state.entries) {
      if (e.value.downloading) next[e.key] = e.value;
    }
    state = next;
  }

  Future<bool> _whisperInstalled(WhisperModelSpec w) async {
    final dir = await _dirOf(w.id);
    final manifest = File('${dir.path}/installed.json');
    if (!await manifest.exists()) return false;
    try {
      final m = jsonDecode(await manifest.readAsString()) as Map<String, dynamic>;
      for (final f in w.files) {
        final file = File('${dir.path}/${w.fileName(f.role)}');
        final rec = m[f.role] as Map<String, dynamic>?;
        if (rec == null || !await file.exists()) return false;
        if (await file.length() != rec['size']) return false; // quick integrity
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<WhisperFiles?> whisperFiles(String id) async {
    final catalog = await ref.read(catalogProvider.future);
    final w = catalog.byId(id);
    if (w == null || !await _whisperInstalled(w)) return null;
    final d = (await _dirOf(id)).path;
    return WhisperFiles(w, '$d/${w.fileName('encoder')}', '$d/${w.fileName('decoder')}',
        '$d/${w.fileName('tokens')}');
  }

  Future<void> download(String id) async {
    final cur = state[id];
    if (cur == null || cur.downloading || cur.kind == PackKind.tts) return;
    _set(cur.copyWith(downloading: true, clearProgress: true, clearError: true));
    try {
      if (cur.kind == PackKind.translation) {
        final ok = await _mlkit.downloadModel(id.substring(6), isWifiRequired: false);
        if (!ok) throw const AppFailure('err_download');
      } else {
        await _downloadWhisper(id);
      }
      _set(state[id]!.copyWith(
          downloading: false, installed: true, hasPartial: false, clearProgress: true));
    } on DownloadCancelled {
      _set(state[id]!.copyWith(downloading: false, hasPartial: true, clearProgress: true));
    } on AppFailure catch (e) {
      _set(state[id]!.copyWith(
          downloading: false, hasPartial: true, errorKey: e.key, clearProgress: true));
    } catch (_) {
      _set(state[id]!.copyWith(
          downloading: false, hasPartial: true, errorKey: 'err_download', clearProgress: true));
    } finally {
      _cancels.remove(id);
    }
  }

  Future<void> _downloadWhisper(String id) async {
    final catalog = await ref.read(catalogProvider.future);
    final w = catalog.byId(id)!;
    final dir = await _dirOf(id);
    await dir.create(recursive: true);
    final token = _cancels[id] = CancelToken();
    final manifest = <String, dynamic>{};
    final approxTotal = w.approxMB * 1024 * 1024;
    var doneBytes = 0;
    for (final f in w.files) {
      final dest = File('${dir.path}/${w.fileName(f.role)}');
      if (!await dest.exists()) {
        await _downloader.download(Uri.parse(f.url), dest,
            expectedSha256: f.sha256, cancel: token, onProgress: (r, _) {
          final p = ((doneBytes + r) / approxTotal).clamp(0.0, 0.99);
          // Throttle UI updates to ~200 steps.
          if (p - (state[id]!.progress ?? 0) >= 0.005) {
            _set(state[id]!.copyWith(progress: p));
          }
        });
      }
      final size = await dest.length();
      doneBytes += size;
      manifest[f.role] = {
        'size': size,
        'sha256': f.sha256.isNotEmpty ? f.sha256 : await sha256OfFile(dest.path),
      };
    }
    await File('${dir.path}/installed.json').writeAsString(jsonEncode(manifest));
  }

  void cancel(String id) => _cancels[id]?.cancel();

  Future<void> delete(String id) async {
    final cur = state[id];
    if (cur == null) return;
    if (cur.kind == PackKind.translation) {
      try {
        await _mlkit.deleteModel(id.substring(6));
      } catch (_) {}
    } else if (cur.kind == PackKind.whisper) {
      final dir = await _dirOf(id);
      if (await dir.exists()) await dir.delete(recursive: true);
    }
    _set(cur.copyWith(installed: false, hasPartial: false, clearError: true));
  }

  /// Full SHA-256 verification against the hashes recorded at install time.
  Future<bool> verify(String id) async {
    final catalog = await ref.read(catalogProvider.future);
    final w = catalog.byId(id);
    if (w == null) return state[id]?.installed ?? false;
    final dir = await _dirOf(id);
    try {
      final m = jsonDecode(await File('${dir.path}/installed.json').readAsString())
          as Map<String, dynamic>;
      for (final f in w.files) {
        final got = await sha256OfFile('${dir.path}/${w.fileName(f.role)}');
        if (got != (m[f.role] as Map)['sha256']) return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// True when translation (AR/DE/EN pivot) and the selected on-device speech
/// engine are installed, i.e. the core flow works in airplane mode.
final offlineReadyProvider = Provider<bool>((ref) {
  final packs = ref.watch(modelServiceProvider);
  final s = ref.watch(settingsProvider);
  bool ok(String id) => packs[id]?.installed ?? false;
  final translation = ModelService.mlkitCodes.every((c) => ok(mlkitPackId(c)));
  final stt = s.sttEngine == SttEngine.whisper ? ok(s.whisperModelId) : true;
  return translation && stt;
});
