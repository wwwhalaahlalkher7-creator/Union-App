# Eino study catalogue context

Eino can now retrieve a small number of relevant study-library catalogue records for an authenticated student. The query is restricted to active materials and subjects in that student's department, and to the student's current semester when one is set. Search terms are bound SQL parameters, capped at six tokens, and the result set is capped at five records.

## Important scope boundary

This is **catalogue metadata retrieval**, not semantic search of PDF contents. It uses material titles, descriptions, subject names, and semester names. Eino is instructed not to claim it has read a file or to fabricate details that are not in the supplied context.

Full study-content RAG should be a separate follow-up: extract/index text from approved Drive PDFs, preserve department/semester access metadata, re-index changed files, remove deleted files from the index, and verify access scope at retrieval time. Do not enable a shared global index without per-record access filters.
