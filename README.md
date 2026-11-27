# Lisancom — مترجم صوتي عربي ⇄ ألماني (يعمل دون إنترنت)

بعد تنزيل حزم اللغات مرة واحدة يعمل التطبيق كاملًا دون إنترنت، حتى في وضع الطيران:
**الكلام → نص (Whisper على الجهاز) → ترجمة (ML Kit على الجهاز) → نطق (أصوات النظام).**

## التشغيل على Windows
1. ثبّت [Flutter](https://docs.flutter.dev/get-started/install/windows) وAndroid Studio (Android SDK).
2. فك الضغط، ثم شغّل `scripts\setup.bat` (أو `scripts\setup.ps1`).
   السكربت ينشئ ملفات المنصات الناقصة، ويثبت الحزم، ويشغّل `analyze` و`test`، ثم يبني `app-debug.apk`.
3. ثبّت التطبيق: `flutter install` مع وصل الهاتف (USB debugging)، أو انسخ الـ APK إلى الهاتف.

## أول تشغيل (مرة واحدة مع إنترنت)
الإعدادات ← **إدارة حزم اللغات** ← نزّل:
- ترجمة: العربية + الألمانية + الإنجليزية (لغة وسيطة) — نحو 30 ميغابايت لكل لغة.
- التعرف على الكلام: **Whisper Base** (نحو 160 ميغابايت، أسرع) أو **Small** (نحو 375 ميغابايت، أدق للعربية).
- النطق: من إعدادات الهاتف ← تحويل النص إلى كلام ← نزّل بيانات العربية والألمانية.

عندما يظهر «جاهز للعمل دون إنترنت» في شاشة المحادثة، فعّل وضع الطيران وجرّب.

## البناء عبر GitHub (Android + iPhone) دون تثبيت Flutter
ارفع المشروع إلى GitHub، وسيبني GitHub Actions تلقائيًا:
- `Lisancom-Android-APK` ← ملف APK للتثبيت على أندرويد.
- `Lisancom-iOS-IPA` ← ملف IPA غير موقّع للتثبيت على الآيفون عبر Sideloadly.
التفاصيل في `docs/BUILD_GITHUB.md`.

## البنية
`lib/core` (اللغات، الإعدادات، الترجمة الداخلية للواجهة، الثيم) ·
`lib/features/{conversation,text_translation,phrasebook,settings,model_manager,speech,translation,tts}`.
كل محرك خلف واجهة مستقلة (`TranslationProvider`، `SpeechRecognizer`، `TtsService`)، لذلك يمكن استبداله دون تغيير الواجهة.

راجع: `PROJECT_STATUS.md` · `KNOWN_ISSUES.md` · `docs/OFFLINE.md` · `THIRD_PARTY_NOTICES.md`.
