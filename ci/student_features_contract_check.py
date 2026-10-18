#!/usr/bin/env python3
"""Regression guard for the activity migration, public student profiles, and engineering tools."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
read = lambda p: (ROOT / p).read_text(encoding='utf-8')
checks = {
    'activity API route': (read('backend/src/index.js'), "path === '/public/activities'"),
    'activity endpoint used by app': (read('flutter/lib/data/repositories/content_repository.dart'), "'/api/v1/public/activities'"),
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
    'student feedback API route': (read('backend/src/index.js'), "path === '/feedback' && request.method === 'POST'"),
    'student feedback is authenticated': (read('backend/src/feedback.js'), 'studentAuth(ctx)'),
    'student feedback is throttled': (read('backend/src/feedback.js'), "COUNT(*) AS count FROM student_feedback_reports"),
    'student feedback form route': (read('flutter/lib/app/router.dart'), "GoRoute(path: '/feedback'"),
    'student feedback repository': (read('flutter/lib/data/repositories/feedback_repository.dart'), "'/api/v1/feedback'"),
    'shake gesture opens feedback': (read('flutter/lib/shared/widgets/trinex_shell.dart'), "context.push('/feedback')"),
    'shake sensor stops while app inactive': (read('flutter/lib/shared/widgets/trinex_shell.dart'), '_stopShakeDetection();'),
    'student downloads route': (read('flutter/lib/app/router.dart'), "GoRoute(path: '/downloads'"),
    'download store uses per-student TRINEX directory': (read('flutter/lib/data/repositories/downloaded_materials_store.dart'), "Directory('${root.path}/TRINEX/${_safeOwner(ownerKey)}')"),
    'android public download path': (read('flutter/android/app/src/main/kotlin/com/leoassociation/app/MainActivity.kt'), 'Environment.DIRECTORY_DOWNLOADS + "/TRINEX/"'),
    'PDF page location is restored per student': (read('flutter/lib/features/materials/pdf_material_viewer.dart'), "_lastPagePreferenceKey = 'trinex_material_last_page_${ownerKey}_$safeMaterialId'"),
    'PDF toolbar indicates page position': (read('flutter/lib/features/materials/pdf_material_viewer.dart'), '_currentPage / _pageCount'),
    'material completion requires XP event': (read('backend/src/academic.js'), "event_type='material_complete' AND source_id=?"),
    'material completion requires last PDF page': (read('backend/src/academic.js'), 'effectivePageCount > 0 && nextPage >= effectivePageCount'),
    'specialty tool stress conversion': (read('flutter/lib/shared/utils/engineering_calculations.dart'), "static double convertStress(double value, String from, String to)"),
    'engineering calculator tests': (read('flutter/test/engineering_calculations_test.dart'), 'converts stress, length, current, and data size units'),
    'specialty tool concrete volume': (read('flutter/lib/shared/utils/engineering_calculations.dart'), 'return length * width * height;'),
    'activity page route': (read('website/activities.html'), 'window.PUBLIC_API_BASE + "/activities"'),
    'learning events retired in migration': (read('backend/migrations/0032_retire_learning_events.sql'), 'DROP TABLE IF EXISTS learning_events;'),
}
errors = [f'{name}: missing {marker!r}' for name, (source, marker) in checks.items() if marker not in source]
if (ROOT / 'website/admin').exists():
    errors.append('Legacy web admin directory must be absent')
if (ROOT / 'backend/src/learning_events.js').exists():
    errors.append('Legacy learning-events module still exists')
if "path === '/public/events'" in read('backend/src/index.js') or "'/events':" in read('backend/src/index.js'):
    errors.append('Legacy public events route remains registered')
if 'learning-events' in read('backend/src/index.js'):
    errors.append('Legacy learning-events routes remain registered')
if errors:
    raise SystemExit('\n'.join(errors))
print(f'Student feature contract check PASS: {len(checks)} contracts')
