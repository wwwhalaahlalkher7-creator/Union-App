# Contributing to TRINEX

## Before changing code

1. Read `README.md` and `docs/ARCHITECTURE.md`.
2. Identify the source of truth for the data you are changing.
3. Check whether the change affects API contract, D1 schema, auth, release version, or deployment.

## Before committing

Run the smallest relevant tests, then the full contract suite when practical:

```bash
python3 ci/verify_project.py
python3 ci/release_check.py
python3 ci/final_release_check.py
```

## Commits

Use short imperative messages, for example:

```text
Fix Eino upstream timeout handling
Add student notification read contract
Harden dashboard moderation action
```

## Documentation rule

Do not create stage/pass README files for ordinary fixes. Update the canonical document in `docs/` or `CHANGELOG.md` when the operational behavior changes.
