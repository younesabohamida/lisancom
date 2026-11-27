import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lisancom/features/model_manager/model_catalog.dart';
import 'package:lisancom/features/phrasebook/phrasebook_screen.dart';
import 'package:lisancom/features/speech/whisper_text_filter.dart';

void main() {
  test('bundled model catalog parses and is complete', () {
    final c = ModelCatalog.parse(File('assets/models/catalog.json').readAsStringSync());
    expect(c.whisper, isNotEmpty);
    for (final w in c.whisper) {
      expect(w.files.map((f) => f.role).toSet(), {'encoder', 'decoder', 'tokens'});
      for (final f in w.files) {
        expect(f.url, startsWith('https://'));
      }
    }
    expect(c.byId('whisper-base'), isNotNull);
  });

  test('bundled phrasebook has AR+DE for every phrase', () {
    final cats = parsePhrasebook(File('assets/phrasebooks/phrases.json').readAsStringSync());
    expect(cats.length, greaterThanOrEqualTo(10));
    for (final c in cats) {
      expect(c.titles.keys, containsAll(['ar', 'de']));
      for (final p in c.phrases) {
        expect(p['ar'], isNotEmpty);
        expect(p['de'], isNotEmpty);
      }
    }
  });

  group('whisper hallucination filter', () {
    test('removes subtitle credits', () {
      expect(cleanWhisperText('ترجمة نانسي قنقر'), '');
      expect(cleanWhisperText('Untertitel im Auftrag des ZDF, 2021'), '');
    });
    test('keeps real speech', () {
      expect(cleanWhisperText('  Ich habe   Kopfschmerzen. '), 'Ich habe Kopfschmerzen.');
    });
    test('removes [Musik] tags', () {
      expect(cleanWhisperText('[Musik] Hallo'), 'Hallo');
    });
  });
}
