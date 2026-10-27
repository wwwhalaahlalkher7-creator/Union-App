# Eino PDF retrieval (Batch 7)

This provides a PDF text-extraction/indexing pipeline and bounded department/semester-scoped chunk retrieval for Eino. New or changed study PDFs are queued automatically by Drive reconciliation, and dashboard uploads queue indexing immediately; the protected admin endpoint remains available for manual retry.

## Index one study PDF

Send an authenticated staff request:

`POST /api/v1/admin/eino/materials/{materialId}/index`

Only `super_admin` and `academic_manager` staff sessions can start indexing. The Worker fetches the file by its stored Google Drive file ID, checks the PDF signature and enforces a 20 MiB download ceiling (aligned with the study-material and exam upload limit), then sends the bytes to the configured OCR route. It stores at most 220 overlapping text chunks (maximum extracted text 240,000 characters) in D1. Re-indexing replaces existing chunks only after extraction succeeds.

The OCR route must be configured in the Worker environment. Mistral OCR is recommended for PDF documents; confirm the provider accepts PDF data URLs in your account. If Google Drive returns an access page rather than a PDF, indexing fails safely and no chunks are replaced.

## Retrieval and boundaries

- Eino retrieves at most four matching chunks from the student's own department, and limits to their current semester when one is selected (semester-less chunks are allowed).
- The retrieved text is treated as untrusted reference material, not as instructions.
- Queries use bound SQL parameters; chunks are capped and ordered; inactive materials/subjects are excluded.
- The system prompt distinguishes extracted text from catalogue metadata and instructs Eino not to invent page numbers or claim unsupported knowledge.
- Guests do not receive academic PDF excerpts.

## Operational limitations

This is text extraction + lexical retrieval, not embeddings/vector search. Image-only PDFs depend on OCR quality. The Worker cron processes a bounded batch each minute; external Drive changes require a successful dashboard sync before they are queued. Production behavior still depends on deployment, the D1 migrations, access permissions for Drive files, and OCR credentials.


## Automatic incremental indexing (Batch 8)

- Successful Drive sync compares each PDF's `drive_modified_at` with its last indexed material state (presence of chunks + Drive modification timestamp). New PDFs, changed PDFs, and PDFs without an index are placed in `eino_material_index_queue`. The dashboard material-upload endpoint also writes the new material row and its queue entry in one D1 batch, so staff do not need a separate sync to begin indexing a just-uploaded PDF.
- The existing one-minute Worker cron processes at most two queued PDFs per run to bound OCR cost and execution time. Failed jobs retry up to three attempts, then remain visible as `failed` in the queue for later operational review.
- When a Drive file disappears from a complete successful index, its chunks are removed and its queue item is cancelled so Eino cannot retrieve stale text. A sync that fails the completeness safeguards does not perform deactivation or stale-index cleanup.
- The admin endpoint remains available for manual re-indexing. OCR provider credentials must be configured. After three failed attempts a job is marked `failed` instead of retrying forever; operational review or a manual retry may then be needed. The queue automation is not active in production until the matching Worker and D1 migration are deployed.

## Relevance ranking (Batch 9)

- Candidate retrieval is department/current-semester scoped and capped at 80 rows before in-memory ranking; only four unique material/chunk pairs are sent to the model.
- Arabic search text is normalized for diacritics, tatweel, alef variants, and final ya; English and Arabic stopwords are excluded from query scoring.
- Ranking favors exact content-token matches, then partial content matches, and gives smaller boosts to material titles and subject names. A matching full phrase receives an additional boost.
- Queries containing only stopwords and queries with no relevant matches return no excerpts rather than injecting arbitrary recent chunks into the prompt.
- This remains bounded lexical ranking, not semantic embeddings. The SQL candidate stage can still miss paraphrases or text with unusual OCR spelling; vector/FTS retrieval would require separate infrastructure and evaluation.

## Candidate-aware relevance scoring (Batch 10)

- Ranking now estimates term rarity within the bounded candidate set, reducing the impact of generic words that appear in many chunks.
- Exact token matches score higher than partial substring matches; exact title and subject tokens receive explicit boosts.
- Full-phrase boosts apply only to multi-token queries, so a single distinctive word found in a chunk cannot accidentally overpower a stronger title match.
- CI covers generic-vs-distinctive terms and title relevance in addition to Arabic normalization, stopwords, unrelated queries, and duplicate removal.
- This remains a small, candidate-local lexical heuristic: its quality depends on which rows the SQL candidate stage retrieves, and it is not a substitute for evaluation against a representative set of real student questions.

## Batch 11: Arabic query variation

The lexical retrieval stage now conservatively expands common Arabic clitics and the definite article (for example, `بالجهد` can match `الجهد` or `جهد`) for both candidate lookup and relevance scoring. Expansion is intentionally limited to common prefixes and does not claim full Arabic stemming or semantic understanding. English terms remain unchanged. The relevance-ranking check includes a regression case for this variation.

## Exam library separation

The Drive index marks PDFs nested under a subject's dedicated `exams` folder (including supported Arabic folder names). The regular study-material reconciliation excludes those files so exam PDFs are not surfaced as ordinary sheets or queued for Eino study-material indexing. The separate `/admin/exams` interface reads the exam-specific Drive index and manages files directly in Drive; it does not alter the student exam UI/API contract.


## PDF upload size and lossless optimization (Batch 15)

- Study-material and exam uploads accept PDF files up to 20 MiB each. The Worker allows the corresponding base64 expansion, while Apps Script decodes the payload and enforces the actual 20 MiB byte limit and PDF signature.
- The admin UI attempts a best-effort, lossless structural rewrite using `pdf-lib` object streams. It never rasterizes pages, down-samples images, or re-encodes image data. It preserves signed/encrypted/interactive or embedded-media PDFs unchanged; if the optimizer cannot load, fails, or does not make the file meaningfully smaller, the original is uploaded.
- This optimization may produce only modest savings on image-heavy scans. The original visual resolution is preferred over aggressive lossy compression. The browser loads the pinned optimizer library from jsDelivr; if that library is unavailable, uploads fall back to the original file.
- PDF OCR indexing now also accepts up to 20 MiB, subject to the configured OCR provider's own limits and timeout.


## Batch 16: upload-to-index reliability

- Dashboard material uploads now create the D1 material row and an Eino indexing queue row in a single batch. This closes the gap where newly uploaded PDFs would not be indexed until a later manual Drive synchronization.
- CI includes a mocked Worker-path integration test that exercises the actual `adminDriveUploadPdf` handler, verifies the Apps Script upload call, checks that the material and queue writes happen together, and confirms the audit log write.
- The test uses mocked Apps Script and D1 interfaces. It does not replace a deployment smoke test against the real Google Drive, Cloudflare Worker, D1 database, and OCR provider.

Batch 16 validation adds a mocked pipeline integration test that invokes the real queue processor, mocks Drive PDF download and the configured OCR provider, then verifies that extracted text is persisted as searchable chunks and the queue moves to `done`. This is an executable code-path test, not a production credential or live-Drive test; production activation still requires deploying the Worker/migrations and configuring the OCR provider secret.

The Batch 16 integration suite also calls the real Drive reconciliation handler against a mocked Apps Script index and mock D1 adapter, asserting stable subject IDs, study-material upsert, automatic PDF queueing, successful-run recording, and exclusion of exam PDFs from the ordinary study-material/index pipeline. This verifies handler control flow; production credentials, actual Google Drive permissions, and live D1 runtime remain environment-level checks.
