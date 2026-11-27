import 'package:flutter_test/flutter_test.dart';
import 'package:lisancom/features/translation/critical_info_guard.dart';

void main() {
  group('numbers', () {
    test('Arabic-Indic digits are normalised', () {
      expect(CriticalInfoGuard.extractNumbers('خذ ٢ حبة كل ٨ ساعات'), ['2', '8']);
    });
    test('decimal comma == decimal dot', () {
      final r = CriticalInfoGuard.check('2,5 mg', '2.5 ملغ');
      expect(r.missingNumbers, isEmpty);
    });
    test('missing number is reported', () {
      final r = CriticalInfoGuard.check('Nehmen Sie 3 Tabletten', 'تناول حبتين');
      expect(r.missingNumbers, ['3']);
    });
    test('number written as word is accepted', () {
      final r = CriticalInfoGuard.check('Ich habe 3 Kinder', 'لدي ثلاثة أطفال');
      expect(r.missingNumbers, isEmpty);
    });
  });

  group('negation', () {
    test('lost German negation is detected', () {
      expect(CriticalInfoGuard.check('Ich bin nicht allergisch', 'أنا مصاب بالحساسية')
          .negationLost, isTrue);
    });
    test('kept negation is fine', () {
      expect(CriticalInfoGuard.check('لا أستطيع التنفس', 'Ich kann nicht atmen')
          .negationLost, isFalse);
    });
    test('Arabic conjunction prefix ولا', () {
      expect(CriticalInfoGuard.hasNegation('ولا أريد'), isTrue);
    });
    test('dialect مش', () {
      expect(CriticalInfoGuard.hasNegation('أنا مش تعبان'), isTrue);
    });
    test('no false positive without negation', () {
      final r = CriticalInfoGuard.check('Guten Tag', 'مرحبا');
      expect(r.hasWarnings, isFalse);
    });
  });
}
