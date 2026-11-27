import 'dart:math' as math;
import 'dart:typed_data';

/// Little-endian PCM16 mono bytes -> Float32 samples in [-1, 1].
Float32List pcm16ToFloat32(Uint8List bytes) {
  final n = bytes.lengthInBytes ~/ 2;
  final out = Float32List(n);
  final data = ByteData.sublistView(bytes);
  for (var i = 0; i < n; i++) {
    out[i] = data.getInt16(i * 2, Endian.little) / 32768.0;
  }
  return out;
}

/// Root-mean-square level of a block (0..1).
double rms(Float32List s) {
  if (s.isEmpty) return 0;
  var sum = 0.0;
  for (final v in s) {
    sum += v * v;
  }
  return math.sqrt(sum / s.length);
}

/// Joins chunks into one contiguous buffer.
Float32List concat(List<Float32List> chunks) {
  final total = chunks.fold<int>(0, (a, c) => a + c.length);
  final out = Float32List(total);
  var o = 0;
  for (final c in chunks) {
    out.setAll(o, c);
    o += c.length;
  }
  return out;
}
