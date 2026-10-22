#!/usr/bin/env python3
"""Guard the new-account-only guided-tour registration transition contract."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
read = lambda path: (ROOT / path).read_text(encoding='utf-8')
auth = read('backend/src/auth.js')
admin_config = read('backend/src/admin/config.js')
register_screen = read('flutter/lib/features/auth/register_screen.dart')
shell = read('flutter/lib/shared/widgets/trinex_shell.dart')

checks = {
    'admin registered flag derives from stored auth hash': (admin_config, 'CASE WHEN auth_secret_hash IS NULL THEN 0 ELSE 1 END AS registered'),
    'registration claims only an unregistered record': (auth, 'WHERE id = ? AND active = 1 AND auth_secret_hash IS NULL'),
    'successful registration emits transition marker': (auth, 'return issueSession(ctx, { studentId: student.id, registrationTransition: true });'),
    'session response reads persisted registration status': (auth, 'CASE WHEN st.auth_secret_hash IS NULL THEN 0 ELSE 1 END AS registered'),
    'transition marker requires persisted registered state': (auth, 'payload.registrationTransition = Boolean(identity.registrationTransition && registered);'),
    'client requires both server status and transition marker': (register_screen, "result['registrationTransition'] == true"),
    'client checks registered status too': (register_screen, "result['registered'] == true"),
    'tour pending is set from the confirmed transition': (register_screen, 'setLearningModePendingFor(studentNumber, shouldStartTour)'),
    'tour excludes guests with no student number': (shell, "if (studentNumber.isEmpty) return; // Guests never see the guided tour."),
}
failures = [f'{name}: missing {marker!r}' for name, (source, marker) in checks.items() if marker not in source]
if failures:
    raise SystemExit('\n'.join(failures))

# Keep this marker out of the ordinary login and refresh call sites.
if auth.count('registrationTransition: true') != 1:
    raise SystemExit('registrationTransition must be emitted only at the successful new-registration call site')

print(f'Registration transition check PASS: {len(checks)} contracts')
