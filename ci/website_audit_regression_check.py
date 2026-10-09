#!/usr/bin/env python3
"""Regression checks for URL validation and safe rendering in public/admin pages."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
checks = {
    'site settings URL parser': ('website/site-settings.js', 'function safeLink(value, protocols = ["https:"])'),
    'mailto protocol allowlist': ('website/site-settings.js', '["mailto:"]'),
    'new-tab opener isolation': ('website/site-settings.js', 'noopener noreferrer'),
    'news image URL validation': ('website/news.html', 'function safeNewsImageUrl(value)'),
    'news card image assignment after validation': ('website/news.html', 'if (imageUrl) card.querySelector(".news-image-wrap img").src = imageUrl;'),
    'news modal image assignment after validation': ('website/news.html', 'if (imageUrl) modalBody.querySelector(".news-modal-image-wrap img").src = imageUrl;'),
    'event gallery URL validation': ('website/events.html', 'function safeEventImageUrl(value)'),
    'achievement gallery URL validation': ('website/Injazat.html', 'function safeAchievementImageUrl(value)'),
    'course links URL validation': ('website/courses.html', 'function safeCourseUrl(value)'),
    'course invalid link rejection': ('website/courses.html', 'رابط الملف غير صالح أو غير آمن'),
    'admin upload filename treated as text': ('website/admin/settings.html', 'document.createTextNode(" " + file.name)'),
}
errors = []
for label, (file, marker) in checks.items():
    content = (ROOT / file).read_text(encoding='utf-8')
    if marker not in content:
        errors.append(f'{label}: missing expected safety invariant in {file}')

# Guard against the specific direct HTML interpolation patterns fixed by this audit.
news = (ROOT / 'website/news.html').read_text(encoding='utf-8')
for marker in ['src="${item.image}"', 'ناشر: ${item.publisher', '${dateString}']:
    if marker in news:
        errors.append(f'Unsafe dynamic HTML interpolation remains in news page: {marker}')
settings = (ROOT / 'website/admin/settings.html').read_text(encoding='utf-8')
if 'hint.innerHTML = `<i class="fa-solid fa-image"></i> ${file.name}`' in settings:
    errors.append('Unsafe uploaded filename HTML interpolation remains')

if errors:
    raise SystemExit('\n'.join(errors))
print(f'website security regression audit: PASS ({len(checks)} invariants)')
