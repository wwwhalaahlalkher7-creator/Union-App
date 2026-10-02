# Backend

Cloudflare Worker + D1 API for the association application.

## Eino provider architecture

Eino is capability-first and routes each task through providers that explicitly advertise support for that capability.
Provider selection is handled by `src/providers/registry.js` and routes each
capability through providers that explicitly advertise support for it.

Current provider configuration:

- `mistral`: primary Text/Vision/OCR provider, with Mistral Small 4 (`mistral-small-2603`) for text/vision and Mistral OCR for documents.
- `groq`: primary STT/TTS provider, with Whisper Large V3 Turbo for transcription and Orpheus Arabic for Arabic speech generation; it is also a text/vision fallback.
- `free.ai`: optional final fallback for capabilities it supports.

Current capability chains:

- Text: Mistral Small 4 → Groq GPT-OSS 120B → Free.ai.
- Vision: Mistral Small 4 → Groq Qwen 3.8 27B → Free.ai.
- OCR: Mistral OCR → Free.ai.
- STT: Groq Whisper Large V3 Turbo → Mistral Voxtral Transcribe → Free.ai.
- TTS: Groq Orpheus Arabic → Mistral Voxtral TTS → Free.ai.

The router selects by capability first and only uses a fallback when the selected provider reports a retryable failure. Provider credentials are never sent to Flutter.

Embeddings remain separately configurable through `EINO_EMBEDDING_BASE_URL`, `EINO_EMBEDDING_API_KEY` and `EINO_EMBEDDING_MODEL`.

## Memory

Student-owned Eino memory is stored canonically in D1. Semantic indexing is
optional through Chroma and a separately configured embedding provider. If the
embedding/Chroma path is unavailable, Eino safely falls back to the D1 memory
records.

## Local environment

For local Worker secrets, copy `backend/.dev.vars.example` to `backend/.dev.vars` and replace the placeholders. The file is ignored by Git and must never contain values that are committed to the repository.

## Source layout

`src/index.js` هو router وWorker entry point فقط. منطق الـAPI موزع على modules بحسب النطاق:
`core.js`, `auth.js`, `public.js`, `student.js`, `academic.js`, `interactions.js`,
`media.js`, `admin.js`, `eino.js`, و`drive.js`.

عند إضافة endpoint جديد، سجّل route في `index.js` وضع handler في module مالك للنطاق.


## إعداد استعادة كلمة مرور الطالب

يستخدم مسار استعادة كلمة مرور الطالب Google Apps Script الموجود أصلًا في المشروع لإرسال رمز مكون من 6 أرقام عبر حساب Gmail المخصص للمشروع. لا يحتاج هذا المسار إلى Google Cloud Console أو Resend.

اضبط سر Worker التالي في بيئة الإنتاج:
- `GOOGLE_APPS_SCRIPT_EMAIL_TOKEN`

وفي Script Properties الخاصة بـ Google Apps Script أضف نفس القيمة باسم `EMAIL_API_TOKEN`. يجب أن يبقى هذا الرمز منفصلًا عن `API_TOKEN` المستخدم لتكامل Google Drive.

الرمز صالح لمدة 10 دقائق، ويُخزن في قاعدة البيانات كـ hash فقط، مع حد أقصى 5 محاولات للرمز. بعد نجاح الاستعادة تُبطل جلسات الطالب السابقة.

إذا لم يكن للطالب بريد مسجل، يعيد الـAPI الخطأ `NO_RECOVERY_EMAIL` برسالة تطلب التواصل مع المسؤولين.
