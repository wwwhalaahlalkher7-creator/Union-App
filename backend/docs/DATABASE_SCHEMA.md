# TRINEX Backend — Database Schema Map

This document describes the **logical organization** of the D1 schema. Migration files remain historical and are not rewritten to make them look cleaner.

## Domains

### 1. Identity & authentication
- `roles` — staff roles.
- `staff_users` — dashboard/admin accounts.
- `students` — student identity and registration state.
- `sessions` — access/refresh sessions; exactly one of `student_id` or `staff_user_id` is set.
- `auth_audit_events` — authentication security events.
- `auth_rate_limits` — IP/action login and refresh throttling.

### 2. Academic structure
- `departments` — engineering departments/specialties.
- `semesters` — academic semesters/years.
- `subjects` — courses, linked to one department and semester.
- `schedules` — timetable entries linked to department/semester and optionally a subject.

### 3. Learning materials
- `materials` — study files linked to subjects and optionally Google Drive.
- `material_progress` — one current progress record per student/material.
- `material_progress_events` — append-only progress events.
- `drive_folder_index` — synchronized Drive folder structure.
- `drive_sync_runs` — Drive synchronization history.

**Historical-semester rule:** student material browsing intentionally is **not restricted to the student's current semester**. A student may select an earlier semester to revisit its courses/materials. The API still restricts materials to the student's department.

### 4. Community & interactions
- `comments` — comments attached polymorphically to supported published content.
- `comment_replies` — replies owned by students and attached to comments.
- `reactions` — reactions on supported content.
- `comment_reactions` — reactions on comments.
- `interaction_rate_limits` — anti-spam windows for comments, replies and reactions.

The application validates that new comments/reactions target an existing published content record before writing a polymorphic reference.

### 5. Public content
- `news`
- `events`
- `activities`
- `achievements`
- `announcements`

These are separate content tables because their fields and lifecycle differ. They are not collapsed into a generic content table.

### 6. Notifications
- `notification_targets` — one announcement target per student.
- `notification_devices` — registered student devices.
- `notification_dispatch_queue` — pending/delivered push and in-app deliveries.

Queue delivery rows are protected by partial unique indexes so repeated/concurrent sends remain idempotent.

### 7. Gamification
- `xp_events` — append-only XP awards.
- `student_stats` — current XP/level aggregate.
- `badges` — badge definitions.
- `student_badges` — awarded badges.

The server enforces the daily XP cap atomically when inserting milestone events.

### 8. Eino
- `eino_usage` — request-window counters.
- `eino_quota_usage` — daily/window/global quota buckets.
- `eino_telemetry` — aggregated operational telemetry.
- `eino_memories` — student-owned D1 memory metadata/ownership; optional vector state is represented by `chroma_id`.

### 9. Administration & configuration
- `app_settings` — dynamic application configuration.
- `audit_logs` — dashboard/admin mutations.

## Important relationship rules

1. Student deletion removes all student-owned child records before deleting the student, including replies authored under another student's comment and Eino memories.
2. Deleting a material/subject remains coupled to Google Drive when a Drive file ID exists: if external deletion fails, the D1 record is not removed.
3. Materials may be read from previous semesters; this is intentional and must not be changed to `semesters.active = 1` filtering in the authenticated material API.
4. Schedules validate that an assigned subject belongs to the same department and semester.
5. Public interaction creation validates the target content instead of allowing orphan polymorphic references.
6. Foreign keys are checked in CI against the complete migration chain.

## Migration policy

`0001` through the current migration are historical source-of-truth. New schema changes must be additive and sequential. Do not edit an already-applied migration in production. If a relationship needs changing, add a new migration with a safe backfill/transition instead.
