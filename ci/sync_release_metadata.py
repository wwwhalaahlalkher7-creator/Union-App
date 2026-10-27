#!/usr/bin/env python3
"""Generate release metadata from the single canonical apps/student/VERSION file."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
VERSION_FILE = ROOT / "apps/student" / "VERSION"
WRANGLER = ROOT / "services/api" / "wrangler.toml"
VERSION_RE = re.compile(r"^\s*(\d+\.\d+\.\d+\+\d+)(?:\s+#.*)?\s*$")

raw_lines = VERSION_FILE.read_text(encoding="utf-8").splitlines()
value = ""
notes = []
for line in raw_lines:
    stripped = line.strip()
    if not stripped:
        continue
    if stripped.startswith("#"):
        note = stripped[1:].strip()
        if note:
            notes.append(note)
        continue
    match = VERSION_RE.fullmatch(line)
    if not match:
        raise SystemExit(f"Invalid apps/student/VERSION value: {stripped!r}")
    if value:
        raise SystemExit("apps/student/VERSION must contain exactly one version value")
    value = match.group(1)

if not value:
    raise SystemExit("apps/student/VERSION must contain exactly one version value")

match = re.fullmatch(r"(\d+)\.(\d+)\.(\d+)\+(\d+)", value)
assert match is not None
version = ".".join(match.group(i) for i in range(1, 4))
release_notes = "\\n".join(notes)

text = WRANGLER.read_text(encoding="utf-8")
text, count = re.subn(r'^APP_VERSION\s*=\s*".*?"$', f'APP_VERSION = "{version}"', text, count=1, flags=re.M)
if count != 1:
    raise SystemExit("APP_VERSION entry not found in services/api/wrangler.toml")

escaped_notes = release_notes.replace('\\', '\\\\').replace('"', '\\"')
text, count = re.subn(r'^APP_RELEASE_NOTES\s*=\s*".*?"$', f'APP_RELEASE_NOTES = "{escaped_notes}"', text, count=1, flags=re.M)
if count != 1:
    raise SystemExit("APP_RELEASE_NOTES entry not found in services/api/wrangler.toml")

UPDATE_URL = "https://ush-eng.great-site.net/download.html"
text, count = re.subn(r'^APP_UPDATE_URL\s*=\s*".*?"$', f'APP_UPDATE_URL = "{UPDATE_URL}"', text, count=1, flags=re.M)
if count != 1:
    raise SystemExit("APP_UPDATE_URL entry not found in services/api/wrangler.toml")

WRANGLER.write_text(text, encoding="utf-8")
print(f"Release metadata synchronized: version={version}, build={match.group(4)}, notes={'yes' if release_notes else 'no'}")
