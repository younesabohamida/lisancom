/// Detects likely loss of critical information (numbers, negation) between
/// source and translation. It never changes the translation; it only produces
/// warnings so the user can repeat or confirm instead of trusting blindly.
class GuardResult {
  const GuardResult({this.missingNumbers = const [], this.negationLost = false});
  final List<String> missingNumbers;
  final bool negationLost;
  bool get hasWarnings => missingNumbers.isNotEmpty || negationLost;
}

class CriticalInfoGuard {
  static const _digitMap = {
    '٠': '0', '١': '1', '٢': '2', '٣': '3', '٤': '4',
    '٥': '5', '٦': '6', '٧': '7', '٨': '8', '٩': '9',
    '۰': '0', '۱': '1', '۲': '2', '۳': '3', '۴': '4',
    '۵': '5', '۶': '6', '۷': '7', '۸': '8', '۹': '9',
    '٫': '.', '٬': '',
  };

  static const _numberWords = {
    'null': '0', 'eins': '1', 'zwei': '2', 'drei': '3', 'vier': '4',
    'fünf': '5', 'sechs': '6', 'sieben': '7', 'acht': '8', 'neun': '9',
    'zehn': '10', 'elf': '11', 'zwölf': '12',
    'صفر': '0', 'واحد': '1', 'واحدة': '1', 'اثنان': '2', 'اثنين': '2',
    'ثلاثة': '3', 'ثلاث': '3', 'أربعة': '4', 'اربعة': '4', 'أربع': '4',
    'خمسة': '5', 'خمس': '5', 'ستة': '6', 'سبعة': '7', 'سبع': '7',
    'ثمانية': '8', 'ثماني': '8', 'تسعة': '9', 'تسع': '9', 'عشرة': '10',
  };

  static const _negations = {
    // German
    'nicht', 'kein', 'keine', 'keinen', 'keinem', 'keiner', 'keines',
    'nie', 'niemals', 'nichts', 'niemand', 'weder', 'ohne',
    // Arabic (MSA + common dialects)
    'لا', 'لم', 'لن', 'ليس', 'ليست', 'لست', 'لسنا', 'ليسوا', 'مش', 'مو',
    'ماني', 'مافي', 'مافيش', 'مفيش', 'بدون', 'دون', 'غير', 'أبدا', 'ابدا',
  };

  static String normalizeDigits(String s) {
    final b = StringBuffer();
    for (final ch in s.split('')) {
      b.write(_digitMap[ch] ?? ch);
    }
    return b.toString();
  }

  static List<String> _tokens(String s) => normalizeDigits(s)
      .toLowerCase()
      .split(RegExp(r'[\s\p{P}]+', unicode: true))
      .where((t) => t.isNotEmpty)
      .toList();

  /// Numbers as written with digits (decimal comma normalised to dot).
  static List<String> extractNumbers(String s) => RegExp(r'\d+(?:[.,]\d+)?')
      .allMatches(normalizeDigits(s))
      .map((m) => m.group(0)!.replaceAll(',', '.'))
      .toList();

  static Set<String> _numbersIncludingWords(String s) => {
        ...extractNumbers(s),
        for (final t in _tokens(s))
          if (_numberWords[t] != null) _numberWords[t]!,
      };

  static bool hasNegation(String s) => _tokens(s).any((t) {
        if (_negations.contains(t)) return true;
        // Arabic conjunction prefixes: ولا / فلا / ومش ...
        if (t.length > 2 && (t.startsWith('و') || t.startsWith('ف'))) {
          return _negations.contains(t.substring(1));
        }
        return false;
      });

  static GuardResult check(String source, String translation) {
    final target = _numbersIncludingWords(translation);
    final missing = extractNumbers(source)
        .where((n) => !target.contains(n))
        .toSet()
        .toList();
    final negLost = hasNegation(source) && !hasNegation(translation);
    return GuardResult(missingNumbers: missing, negationLost: negLost);
  }
}
