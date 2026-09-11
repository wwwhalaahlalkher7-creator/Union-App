# عقد المصادقة V1.1

## Student login
`POST /api/v1/auth/login`
```json
{"studentNumber":"...","password":"..."}
```

## Staff login
`POST /api/v1/auth/staff/login`
```json
{"email":"admin@example.com","password":"..."}
```

## Staff bootstrap
Header: `X-Staff-Bootstrap-Token`

`POST /api/v1/auth/staff/bootstrap`
```json
{"email":"admin@example.com","displayName":"مدير الرابطة","password":"..."}
```

## Session
`Authorization: Bearer <accessToken>`

Refresh token rotation is mandatory; clients must replace the old refresh token with the returned one.
