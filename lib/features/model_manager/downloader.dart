import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../../core/errors.dart';

class CancelToken {
  bool cancelled = false;
  void cancel() => cancelled = true;
}

class DownloadCancelled implements Exception {}

/// Resumable HTTP download into `<dest>.part`, renamed to `dest` on success.
class Downloader {
  Downloader([http.Client? client]) : _client = client ?? http.Client();
  final http.Client _client;

  Future<void> download(
    Uri url,
    File dest, {
    String expectedSha256 = '',
    void Function(int received, int? total)? onProgress,
    CancelToken? cancel,
  }) async {
    final part = File('${dest.path}.part');
    await part.parent.create(recursive: true);
    var start = await part.exists() ? await part.length() : 0;

    final req = http.Request('GET', url);
    if (start > 0) req.headers['Range'] = 'bytes=$start-';
    final resp = await _client.send(req);

    if (resp.statusCode == 416 && start > 0) {
      // Already complete.
      await resp.stream.drain<void>();
    } else {
      if (resp.statusCode == 200) {
        start = 0; // server ignored Range -> restart
      } else if (resp.statusCode != 206) {
        await resp.stream.drain<void>();
        throw AppFailure('err_download', 'HTTP ${resp.statusCode}');
      }
      final total = resp.contentLength == null ? null : start + resp.contentLength!;
      final sink = part.openWrite(mode: start > 0 ? FileMode.append : FileMode.write);
      var received = start;
      try {
        await for (final chunk in resp.stream) {
          if (cancel?.cancelled ?? false) throw DownloadCancelled();
          sink.add(chunk);
          received += chunk.length;
          onProgress?.call(received, total);
        }
      } on FileSystemException catch (e) {
        throw AppFailure(_isNoSpace(e) ? 'err_storage_full' : 'err_download', e);
      } finally {
        await sink.close();
      }
      if (total != null && received < total) {
        throw const AppFailure('err_download', 'incomplete');
      }
    }

    if (expectedSha256.isNotEmpty) {
      final got = await sha256OfFile(part.path);
      if (got != expectedSha256.toLowerCase()) {
        await part.delete();
        throw const AppFailure('verify_bad');
      }
    }
    if (await dest.exists()) await dest.delete();
    await part.rename(dest.path);
  }

  static bool _isNoSpace(FileSystemException e) =>
      e.osError?.errorCode == 28 /* ENOSPC */ ||
      (e.osError?.message.toLowerCase().contains('space') ?? false);
}

/// SHA-256 of a file computed off the UI isolate.
Future<String> sha256OfFile(String path) => Isolate.run(() async =>
    (await sha256.bind(File(path).openRead()).first).toString());
