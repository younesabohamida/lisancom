/// Whisper is known to "hallucinate" subtitle credits on silence/noise,
/// especially for Arabic and German. Strip those so they are never translated.
const _hallucinations = [
  'ترجمة نانسي قنقر',
  'نانسي قنقر',
  'اشتركوا في القناة',
  'اشترك في القناة',
  'شكرا للمشاهدة',
  'شكراً للمشاهدة',
  'Untertitel im Auftrag des ZDF',
  'Untertitelung im Auftrag des ZDF',
  'Untertitel der Amara.org-Community',
  'Untertitel von Stephanie Geiges',
  'Vielen Dank fürs Zuschauen',
  "Vielen Dank für's Zuschauen",
  'Copyright WDR',
];

String cleanWhisperText(String raw) {
  var t = raw;
  var removed = false;
  for (final h in _hallucinations) {
    final re = RegExp(RegExp.escape(h), caseSensitive: false);
    if (re.hasMatch(t)) {
      removed = true;
      t = t.replaceAll(re, '');
    }
  }
  t = t.replaceAll(RegExp(r'\[[^\]]*\]|\([^)]*(Musik|music|موسيقى)[^)]*\)',
      caseSensitive: false), '');
  t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
  // A credit line was removed and no words remain (e.g. ", 2021").
  if (removed && !RegExp(r'\p{L}', unicode: true).hasMatch(t)) return '';
  // Only punctuation left -> nothing was said.
  if (RegExp(r'^[\p{P}\s]*$', unicode: true).hasMatch(t)) return '';
  return t;
}
