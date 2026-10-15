# Structured import extraction

The admin scanner now prioritizes structured vision extraction for image/PDF imports instead of presenting the full OCR transcript as review data.

- Student imports request only student number, full name, and optional email.
- Schedule imports request only subject, weekday, start/end time, room, and lecturer when visible.
- Non-record metadata (logos, seals, university/college headings, signatures, and footer text) is explicitly excluded.
- Returned records are normalized, checked for required fields, and deduplicated before review.
- If structured vision is unavailable or returns unusable data, the app falls back to OCR and attempts to parse Markdown timetable matrices. It never displays the entire OCR transcript in the review notes.
- No records are committed without the existing validation and supervisor approval flow.

The app calls the existing `/eino/vision` endpoint. The backend now recognizes provider responses that return their generated content under `answer` as well as `text`, and forwards the requested extraction prompt to the Free.ai vision adapter.

Validation performed here: backend JavaScript syntax check (`npm run check`) passed. Flutter analyze/build could not be run in this environment because Flutter/Dart are not installed.
