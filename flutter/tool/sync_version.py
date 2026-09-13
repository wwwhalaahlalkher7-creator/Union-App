#!/usr/bin/env python3
"""Synchronize the single Flutter release version into generated project files."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
version = (ROOT / "VERSION").read_text(encoding="utf-8").strip()
match = re.fullmatch(r"(\d+)\.(\d+)\.(\d+)\+(\d+)", version)
if not match:
    raise SystemExit("VERSION must use MAJOR.MINOR.PATCH+BUILD")

name = ".".join(match.group(i) for i in range(1, 4))
build_number = match.group(4)

pubspec = ROOT / "pubspec.yaml"
text = pubspec.read_text(encoding="utf-8")
text, count = re.subn(
    r"^version: .*?$",
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
