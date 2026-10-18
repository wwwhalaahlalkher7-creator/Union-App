#!/usr/bin/env python3
"""Synchronize the canonical Flutter release version into generated project files."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
VERSION_FILE = ROOT / "VERSION"
VERSION_RE = re.compile(r"^\s*(\d+\.\d+\.\d+\+\d+)(?:\s+#.*)?\s*$")


def read_version() -> str:
    values = []
    for line in VERSION_FILE.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        match = VERSION_RE.fullmatch(line)
        if not match:
            raise SystemExit(f"Invalid VERSION value: {stripped!r}")
        values.append(match.group(1))
    if len(values) != 1:
        raise SystemExit("flutter/VERSION must contain exactly one version value")
    return values[0]


version = read_version()
match = re.fullmatch(r"(\d+)\.(\d+)\.(\d+)\+(\d+)", version)
# read_version already validates the complete value; this keeps the generated fields explicit.
assert match is not None

name = ".".join(match.group(i) for i in range(1, 4))
build_number = match.group(4)

pubspec = ROOT / "pubspec.yaml"
text = pubspec.read_text(encoding="utf-8")
text, count = re.subn(
    r"^version:\s*.*?$",
    f"version: {version}",
    text,
    count=1,
    flags=re.M,
)
if count != 1:
    raise SystemExit("pubspec.yaml version field not found")
pubspec.write_text(text, encoding="utf-8")

dart = ROOT / "lib/core/app_version.dart"
dart.write_text(
    "/// Generated from flutter/VERSION.\n"
    "/// Do not edit release numbers here by hand.\n"
    "class AppVersion {\n"
    "  const AppVersion._();\n\n"
    f"  static const name = '{name}';\n"
    f"  static const build = {build_number};\n"
    "  static const full = '$name+$build';\n"
    "  static const version = name;\n"
    "}\n",
    encoding="utf-8",
)

print(f"Synchronized Flutter version: {version}")
