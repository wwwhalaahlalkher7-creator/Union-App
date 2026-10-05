# TRINEX XP Rewards

## Study materials

Material XP is based on **new PDF pages reached**, not file size.

- **1 XP** for each newly reached page.
- **+10 XP** once the material reaches 100% completion.
- A page reward is recorded once per student/material/page; revisiting a page cannot farm XP.
- The backend uses the PDF page count to calculate an integer progress percentage from **0% to 100%**. No decimal percentages are stored or shown.
- Progress and XP are locked until the student has spent about **60 seconds** in the material.
- After the one-minute gate, progress can move in normal 1%-granularity based on the reached page.
- The existing **15-second** server rate limit remains in place.
- The student-wide daily XP cap remains **500 XP**.

The one-minute gate prevents simply opening a PDF and immediately farming XP. File size is deliberately not used because PDF size is a poor proxy for educational content.

## Learning events

TRINEX also has a separate **Learning Events** system. Events are independent activities that can have different visual designs and a configurable XP reward (0–100 XP).

When a published event is created:

1. TRINEX creates the event.
2. An in-app/push-ready notification is automatically created for its target students.
3. The notification contains the event name and possible XP reward.
4. Tapping the notification opens the event directly.
5. Students can also open **More → Events**.
6. Completing an event awards its XP once per student, subject to the same 500 XP daily cap.

Supported event designs currently include `standard`, `challenge`, and `checklist`; their configuration is stored as JSON so additional designs can be added later without redesigning the database.
