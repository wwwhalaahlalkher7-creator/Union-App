# Student Identity & Authentication Audit — Phase 2

## Identity ownership

- `students.id` is the canonical internal student identity.
- `students.student_number` is the academic identifier used to claim an existing record during registration.
- `department_id` and `current_semester_id` are academic records owned by administration.
- Registration cannot overwrite department or current semester.

## Session boundary

Every session belongs to exactly one identity:

- student session → `student_id` only
- staff session → `staff_user_id` only

Both D1 triggers and `studentAuth()` / `staffAuth()` enforce this boundary.

## Flutter token lifecycle

- Access and refresh tokens are stored in `FlutterSecureStorage`.
- Authentication endpoints are never retried through an existing refresh token.
- Refresh rotation is single-flight inside `ApiClient`, preventing concurrent 401 responses from racing the same refresh token.
- A failed refresh clears the local session.

## Academic data access

Student endpoints derive the student identity from `session.student_id`; Flutter does not supply a trusted student ID for authorization.

- Materials: restricted to the session student's department.
- Schedule: restricted to the session student's department.
- Progress, XP, badges, notifications: restricted to `session.student_id`.
- Comments, replies and reactions: authored/owned by `session.student_id`.

## Semester rule

The official current semester is read-only for students. Historical browsing is performed through GET query parameters and does not mutate the student record.
