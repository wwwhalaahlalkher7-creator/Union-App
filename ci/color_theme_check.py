#!/usr/bin/env python3
"""Color/theme hardening guard for the Flutter design system.

Intentional illustration/tool colors are allow-listed because they represent
real-world objects (Eino avatar skin/hair and resistor bands), not UI theme
colors. New UI colors should live in core/theme/design_tokens.dart or be
provided by Theme.of(context).colorScheme.
"""
from pathlib import Path
import re, sys

root = Path('flutter/lib')
theme_files = {
    Path('flutter/lib/core/theme/app_theme.dart'),
    Path('flutter/lib/core/theme/design_tokens.dart'),
}
allow = {
    Path('flutter/lib/features/eino/eino_face.dart'),
    Path('flutter/lib/features/tools/tools_screen.dart'),
}
hex_re = re.compile(r'\b(?:const\s+)?Color\(0x[0-9A-Fa-f]{8}\)')
violations = []
for p in root.rglob('*.dart'):
    if p in theme_files or p in allow:
        continue
    text = p.read_text(encoding='utf-8', errors='ignore')
    for m in hex_re.finditer(text):
        violations.append(f'{p}:{text.count(chr(10), 0, m.start()) + 1}: {m.group(0)}')

if violations:
    print('COLOR THEME CHECK FAILED')
    print('\n'.join(violations))
    sys.exit(1)

print('COLOR THEME CHECK PASSED')
print('UI theme colors are centralized in core/theme/design_tokens.dart / ColorScheme.')
print('Intentional Eino illustration and engineering-tool colors are allow-listed.')
