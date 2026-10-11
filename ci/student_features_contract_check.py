#!/usr/bin/env python3
"""Regression guard for the activity migration, public student profiles, and engineering tools."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
read = lambda p: (ROOT / p).read_text(encoding='utf-8')
checks = {
    'activity API route': (read('backend/src/index.js'), "path === '/public/activities'"),
    'activity endpoint used by app': (read('flutter/lib/data/repositories/content_repository.dart'), "'/api/v1/public/activities'"),
    'activities admin date field': (read('website/admin/js/api-adapter.js'), "labelPlural: 'الأنشطة', dateField: 'Date'"),
    'public profile route': (read('backend/src/index.js'), "publicStudentProfile(ctx, decodeURIComponent(path.split('/')[3]))"),
    'public profile safe serializer': (read('backend/src/public.js'), 'st.full_name AS fullName'),
    'public profile excludes account identifiers': (read('backend/src/public.js'), 'Deliberately omit student number, email, auth fields'),
    'Flutter profile fetch': (read('flutter/lib/data/repositories/student_repository.dart'), "'/api/v1/public/students/$safeId'"),
    'profile screen loads from API': (read('flutter/lib/features/student/student_public_profile_screen.dart'), 'AppDependencies.instance.student.publicProfile(widget.studentId)'),
    'comment author profile link': (read('flutter/lib/features/news/content_comments_sheet.dart'), "'/student/profile/${Uri.encodeComponent(comment.studentId)}"),
    'general chat route': (read('flutter/lib/app/router.dart'), "GoRoute(path: '/general-chat'"),
    'general chat loads authenticated messages': (read('flutter/lib/features/chat/general_chat_screen.dart'), '_repository.messages()'),
    'general chat sends messages': (read('flutter/lib/features/chat/general_chat_screen.dart'), '_repository.send(text, replyToMessageId:'),
    'general chat reply action': (read('flutter/lib/features/chat/general_chat_screen.dart'), "title: Text(l10n.t('reply'))"),
    'general chat swipe reply': (read('flutter/lib/features/chat/general_chat_screen.dart'), 'onHorizontalDragEnd:'),
    'general chat stores reply relation': (read('backend/src/chat.js'), 'reply_to_message_id'),
    'general chat supports reporting': (read('flutter/lib/features/chat/general_chat_screen.dart'), '_repository.report('),
    'general chat periodic refresh': (read('flutter/lib/features/chat/general_chat_screen.dart'), 'Timer.periodic(const Duration(seconds: 5)'),
    'specialty tool stress conversion': (read('flutter/lib/shared/utils/engineering_calculations.dart'), "static double convertStress(double value, String from, String to)"),
    'engineering calculator tests': (read('flutter/test/engineering_calculations_test.dart'), 'converts stress, length, current, and data size units'),
    'specialty tool concrete volume': (read('flutter/lib/shared/utils/engineering_calculations.dart'), 'return length * width * height;'),
    'activity page route': (read('website/activities.html'), 'window.PUBLIC_API_BASE + "/activities"'),
    'admin activity tab': (read('website/admin/content.html'), "['news', 'activities', 'achievements']"),
    'learning events retired in migration': (read('backend/migrations/0032_retire_learning_events.sql'), 'DROP TABLE IF EXISTS learning_events;'),
}
errors = [f'{name}: missing {marker!r}' for name, (source, marker) in checks.items() if marker not in source]
if (ROOT / 'backend/src/learning_events.js').exists():
    errors.append('Legacy learning-events module still exists')
if "path === '/public/events'" in read('backend/src/index.js') or "'/events':" in read('backend/src/index.js'):
    errors.append('Legacy public events route remains registered')
if 'learning-events' in read('backend/src/index.js'):
    errors.append('Legacy learning-events routes remain registered')
if errors:
    raise SystemExit('\n'.join(errors))
print(f'Student feature contract check PASS: {len(checks)} contracts')
