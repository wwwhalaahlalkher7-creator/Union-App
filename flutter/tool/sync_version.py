#!/usr/bin/env python3
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
version = (ROOT / "VERSION").read_text().strip()
match = re.fullmatch(r"(\d+)\.(\d+)\.(\d+)\+(\d+)", version)
if not match:
    raise SystemExit("VERSION must use MAJOR.MINOR.PATCH+BUILD")
name = ".".join(match.group(i) for i in range(1, 4))
build = match.group(4)

pubspec = ROOT / "pubspec.yaml"
text = pubspec.read_text()
text, count = re.subn(r"^version: .*?$", f"version: {version}", text, count=1, flags=re.M)
if count != 1:
    raise SystemExit("pubspec.yaml version field not found")
pubspec.write_text(text)

dart = ROOT / "lib/core/app_version.dart"
dart.write_text(
    "/// Generated from flutter/VERSION.\\n"
    "/// Do not edit release numbers here by hand.\\n"
    "class AppVersion {\\n"
    "  const AppVersion._();\\n\\n"
    f"  static const name = '{name}';\\n"
    f"  static const build = {build};\\n"
    "  static const full = '$name+$build';\\n"
    "}\\n"
)
print(f"Synchronized Flutter version: {version}")
