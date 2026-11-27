import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lisancom/core/audio_utils.dart';

void main() {
  test('pcm16 -> float32', () {
    final b = ByteData(6)
      ..setInt16(0, 0, Endian.little)
      ..setInt16(2, 16384, Endian.little)
      ..setInt16(4, -32768, Endian.little);
    final f = pcm16ToFloat32(b.buffer.asUint8List());
    expect(f, [0.0, 0.5, -1.0]);
  });

  test('odd trailing byte is ignored', () {
    expect(pcm16ToFloat32(Uint8List(3)).length, 1);
  });

  test('rms and concat', () {
    final a = Float32List.fromList([0.5, -0.5]);
    expect(rms(a), closeTo(0.5, 1e-6));
    expect(concat([a, Float32List.fromList([1])]).length, 3);
    expect(rms(Float32List(0)), 0);
  });
}
