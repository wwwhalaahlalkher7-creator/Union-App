# TRINEX Public API Contract

This contract is for the public website migration. The public website is read-only: no anonymous likes, comments, reactions, suggestions/reports, or commercial advertising APIs are part of this contract.

Base URL:
`https://leo-association-api.www-halaahlalkher7.workers.dev/api/v1`

## Read-only endpoints

- `GET /health`
- `GET /version`
- `GET /public/news`
- `GET /public/announcements`
- `GET /public/activities`
- `GET /public/achievements`
- `GET /public/settings`
- `GET /public/materials`

All successful responses use:

```json
{
  "success": true,
  "data": {},
  "meta": {}
}
```

## Public materials

`GET /public/materials` returns the public academic-material index without requiring authentication. It is a TRINEX-native hierarchical contract; it does not reproduce the old Apps Script/Airtable record shape.

Optional query parameters:
- `departmentId`
- `semesterId`
- `subjectId`
- `limit` (1–1000, default 1000)

The response is:

```json
{
  "success": true,
  "data": {
    "departments": [
      {
        "id": "...",
        "name": "...",
        "nameEn": "...",
        "code": "...",
        "semesters": [
          {
            "id": "...",
            "name": "...",
            "nameEn": "...",
            "number": 1,
            "subjects": [
              {
                "id": "...",
                "code": "...",
                "name": "...",
                "nameEn": "...",
                "files": [
                  {
                    "id": "...",
                    "name": "...",
                    "mimeType": "application/pdf",
                    "sizeBytes": 123456,
                    "viewUrl": "...",
                    "downloadUrl": "...",
                    "modifiedAt": "..."
                  }
                ]
              }
            ]
          }
        ]
      }
    ]
  },
  "meta": {
    "source": "d1",
    "count": 1,
    "limit": 1000
  }
}
```

Only active departments, semesters, subjects, and materials are returned. The optional filters narrow the same public dataset and require no student session.

The API exposes Drive viewing/downloading URLs because these materials are part of the public website's academic-material access. It does not expose anonymous open-count analytics.


## Publication semantics

For public content, only rows with `status = 'published'` are returned. Where the endpoint has a publication/event/achievement date, rows dated in the future are not returned. News and announcements whose `expiresAt` has passed are excluded. No authenticated session is required for these read-only endpoints.

## Public content fields

The content endpoints return a normalized website-safe contract rather than raw D1 rows:

- News: `id`, `title`, `body`, `imageUrl`, `category`, `publisher`, `publishAt`, `expiresAt`, `createdAt`, `updatedAt`
- Activities: `id`, `title`, `body`, `imageUrl`, `location`, `publisher`, `eventAt`, `endAt`, `createdAt`, `updatedAt`
- Achievements: `id`, `title`, `description`, `intro`, `highlightsTitle`, `highlights`, `badge`, `publisher`, `imageUrl`, `images`, `achievedAt`, `createdAt`, `updatedAt`
- Announcements: `id`, `title`, `body`, `type`, `targetDepartmentId`, `targetSemesterId`, `publishAt`, `expiresAt`, `createdAt`, `updatedAt`
- Settings: public key/value object under `data`

## Deliberately excluded

The public API does not expose anonymous:

- likes/reactions
- comments/replies
- suggestions/reports
- commercial advertisements
- Apps Script/Airtable operational endpoints
