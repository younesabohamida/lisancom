import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lisancom/core/l10n_strings.dart';

void main() {
  test('every language has exactly the same keys', () {
    final ar = l10nStrings['ar']!.keys.toSet();
    final de = l10nStrings['de']!.keys.toSet();
    expect(ar.difference(de), isEmpty, reason: 'missing in de');
    expect(de.difference(ar), isEmpty, reason: 'missing in ar');
  });

  test('no empty translations and placeholders match', () {
    final ph = RegExp(r'\{(\w+)\}');
    for (final key in l10nStrings['ar']!.keys) {
      final a = l10nStrings['ar']![key]!, d = l10nStrings['de']![key]!;
      expect(a.trim(), isNotEmpty, reason: key);
      expect(d.trim(), isNotEmpty, reason: key);
      expect(ph.allMatches(a).map((m) => m[1]).toSet(),
          ph.allMatches(d).map((m) => m[1]).toSet(), reason: key);
    }
  });

  test('every key used in lib/ exists', () {
    final used = <String>{};
    final re = RegExp(r"""\.tr\(\s*'([a-z0-9_]+)'""");
    final cond = RegExp(r"""'((?:err|warn|tts|stt|settings|theme|pack)_[a-z0-9_]+|ready_offline|not_ready_offline|installed|not_installed|verify_ok|verify_bad|resume|download|listening|recognizing|translating|talk_ar|talk_de|max_duration)'""");
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart') || f.path.contains('l10n_strings')) continue;
      final src = f.readAsStringSync();
      used.addAll(re.allMatches(src).map((m) => m[1]!));
      used.addAll(cond.allMatches(src).map((m) => m[1]!));
    }
    final missing = used.difference(l10nStrings['de']!.keys.toSet());
    expect(missing, isEmpty);
  });

  test('no hard-coded user-facing Text literals in features', () {
    // Allowed: language self-names and emoji icons.
    final re = RegExp(r"""Text\(\s*'([^']*[A-Za-zء-ي][^']*)'""");
    const allowed = {'العربية', 'Deutsch', 'English'};
    for (final f in Directory('lib/features').listSync(recursive: true).whereType<File>()) {
      for (final m in re.allMatches(f.readAsStringSync())) {
        if (m[1]!.contains(r'$')) continue; // interpolated, built from tr()
        expect(allowed, contains(m[1]), reason: '${f.path}: ${m[1]}');
      }
    }
  });
}
