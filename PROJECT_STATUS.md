# PROJECT_STATUS — Lisancom V0.2 (2026-11-27)

الحالات: Not Started · In Progress · Implemented · Tested · Verified on Real Device · Blocked · Production Ready

> بيئة التطوير لم تحتوِ على Flutter SDK، لذلك **لم يُبنَ الكود ولم تُشغَّل الاختبارات بعد**.
> أعلى حالة ممكنة الآن هي **Implemented**. تتحول إلى Tested بعد `scripts/setup.bat` أو GitHub Actions.

| الميزة | الحالة | ملاحظات |
|---|---|---|
| واجهة عربية/ألمانية + RTL/LTR + لغة الجهاز + الألمانية احتياطيًا | Implemented | بدون codegen؛ اختبار تطابق المفاتيح |
| المحادثة اليدوية بزرين كبيرين | Implemented | لا تسجيل أثناء النطق لمنع الصدى |
| التعرف على الكلام دون إنترنت (Whisper / sherpa-onnx) | Implemented | Isolate منفصل؛ غير متدفق (يُعرض النص بعد الإيقاف) |
| التعرف الأصلي للهاتف (اختياري، onDevice) | Implemented | يرفض الشبكة في وضع «على الجهاز فقط» |
| الترجمة دون إنترنت (ML Kit) | Implemented | عبر الإنجليزية كلغة وسيطة |
| النطق (TTS النظام) + فحص توفر الصوت دون إنترنت | Implemented | |
| إدارة الحزم: تنزيل/استكمال/إلغاء/حذف/تحقق SHA-256 | Implemented | |
| مؤشر «جاهز دون إنترنت» | Implemented | |
| حارس المعلومات الحرجة (الأرقام والنفي) | Implemented | تحذير فقط، لا يغيّر الترجمة |
| فلتر هلوسات Whisper | Implemented | |
| الترجمة النصية | Implemented | |
| دليل العبارات دون إنترنت (11 فئة، 53 عبارة) | Implemented | |
| وضع كبار السن (خط أكبر، تباين، أزرار، اهتزاز) | Implemented | |
| الإعدادات + الخصوصية (لا تخزين للصوت أو المحادثات) | Implemented | |
| CI (analyze + test + APK) | Implemented | `.github/workflows/ci.yml` |
| المحادثة التلقائية + VAD + اكتشاف اللغة | Not Started | المرحلة 3 |
| Face-to-Face | Not Started | المرحلة 3 |
| TTS محلي بنماذج Piper/sherpa | Not Started | بديل عند غياب أصوات النظام |
| Germany/Medical Mode، المصطلحات | Not Started | المرحلة 4 |
| الكاميرا/OCR، المستندات، السجل، Bluetooth | Not Started | المرحلة 5 |
| الوثائق البحثية الكاملة (منافسون، تراخيص، Benchmarks) | Not Started | |

## الخطوة التالية
1. تشغيل `scripts/setup.bat` وإصلاح أي خطأ بناء (أرسل لي المخرجات).
2. اختبار على هاتف حقيقي في وضع الطيران (`docs/OFFLINE.md`).
3. المرحلة 3: VAD (Silero عبر sherpa-onnx) + محادثة تلقائية + Face-to-Face.
