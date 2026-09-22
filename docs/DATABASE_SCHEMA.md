# TRINEX Backend — Database Schema Map

This document is the canonical human-readable map of the D1 schema. Migration files remain the historical source of truth; this map groups the tables by responsibility so new features do not create unrelated tables or cross-domain coupling.

## 1. Identity & access

| Table | Responsibility | Main relations |
|---|---|---|
| `roles` | Admin roles | referenced by `staff_users` |
| `staff_users` | Dashboard/admin accounts | sessions, content audit ownership |
| `students` | Student identity/profile/auth | department, semester, all student-owned data |
| `sessions` | Short-lived student/staff sessions | exactly one of student/staff |
| `auth_audit_events` | Auth security events | actor identity only |
| `auth_rate_limits` | Hashed-IP auth buckets | no user FK |
| `interaction_rate_limits` | Student interaction buckets | student |

## 2. Academic catalog

| Table | Responsibility | Main relations |
|---|---|---|
| `departments` | Engineering departments | students, subjects, schedules |
| `semesters` | Academic terms | students, subjects, schedules |
| `subjects` | Course/subject catalog | semester + department |
| `schedules` | Timetable entries | semester + department + optional subject |

**Invariant:** a subject belongs to one department and one semester. Schedule CRUD verifies that its optional subject belongs to the same department/semester.

## 3. Learning materials

| Table | Responsibility | Main relations |
|---|---|---|
| `materials` | Drive-backed study files | subject |
| `material_progress` | Current student progress | student + material |
| `material_progress_events` | Progress event history | student + material |
| `drive_sync_runs` | Drive synchronization runs | operational |
| `drive_folder_index` | Drive folder/file index | operational |

**Semester access policy:** students may explicitly browse materials from previous semesters. Material lookup is constrained by the student's department, but not by the student's current semester. Archived semesters remain browseable when their records still exist.

**Drive deletion policy:** deleting a material/subject first deletes the corresponding Drive files. If Drive deletion fails, D1 deletion is aborted and a `502 DRIVE_DELETE_FAILED` response is returned.

## 4. Community & interactions

| Table | Responsibility | Main relations |
|---|---|---|
| `comments` | Content comments | student + logical content reference |
| `comment_replies` | Replies to comments | comment + student |
| `comment_reactions` | Reactions to comments | comment + student |
| `reactions` | Reactions to news/events/etc. | student + logical content reference |

Logical content types are validated in the API: `news`, `event`, `activity`, `announcement`, `achievement`.

## 5. Public content

| Table | Responsibility |
|---|---|
| `news` | News articles |
| `announcements` | Announcements and notification source records |
| `events` | Events |
| `activities` | Activities |
| `achievements` | Achievement posts |

Public serializers expose only public-safe fields rather than returning raw rows.

## 6. Notifications

| Table | Responsibility | Main relations |
|---|---|---|
| `notification_targets` | One announcement → one student target | announcement + student |
| `notification_devices` | Active push devices | student |
| `notification_dispatch_queue` | Delivery work queue | target + optional device |

Notification send is set-based and idempotent. Re-sending an announcement does not intentionally create another target or duplicate delivery row.

## 7. Progress & gamification

| Table | Responsibility |
|---|---|
| `xp_events` | Immutable XP awards |
| `student_stats` | Current XP/level aggregate |
| `badges` | Badge definitions |
| `student_badges` | Awarded badges |

The daily XP cap is enforced in the database insert condition rather than with a JavaScript read-then-write check.

## 8. Eino

| Table | Responsibility |
|---|---|
| `eino_usage` | Gateway request counters |
| `eino_quota_usage` | Daily quota counters |
| `eino_telemetry` | Operational telemetry |
| `eino_memories` | D1 ownership/consent metadata for Chroma memories |

Eino memory vectors remain external to D1; D1 remains the ownership/metadata authority.

## 9. Application administration

| Table | Responsibility |
|---|---|
| `app_settings` | Dynamic application/site settings |
| `audit_logs` | Dashboard CRUD audit trail |

## Migration policy

- Never rewrite an already-applied migration merely to make it prettier.
- New schema changes use the next sequential migration number.
- Migrations should be additive and reversible in intent; destructive operations require an explicit data-preservation plan.
- `0023` and `0024` are hardening/index migrations; they do not rename or remove historical tables.
- Duplicate historical `CREATE INDEX IF NOT EXISTS` statements are retained because migration history is immutable; new code should not add another equivalent index without checking the schema map first.
