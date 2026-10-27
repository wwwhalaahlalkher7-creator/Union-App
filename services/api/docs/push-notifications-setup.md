# TRINEX push-notification dispatcher

The Worker now drains queued Firebase Cloud Messaging (FCM HTTP v1) deliveries on its scheduled trigger. It sends a bounded batch, uses exponential retry delays for transient failures, and deactivates device tokens that FCM reports as unregistered/invalid.

## Required production setup

1. Create or select the Firebase project used by the Android app and enable Firebase Cloud Messaging.
2. Create a service account with the minimum required Firebase Cloud Messaging send permission. Download its JSON key securely.
3. From `services/api/`, set the JSON as a Cloudflare Worker secret (do not commit it):

   ```sh
   npx wrangler secret put FCM_SERVICE_ACCOUNT_JSON
   ```

   Paste the complete service-account JSON when prompted. The Worker expects `project_id`, `client_email`, and `private_key`.
4. Deploy the Worker with `npx wrangler deploy` and confirm the scheduled trigger is enabled in Cloudflare.
5. Configure the Flutter client using Firebase project values from Firebase Console → Project settings → General → Your apps → Android app (`com.leoassociation.app`). Pass these public client values to your Flutter build as `--dart-define` values:

   ```sh
   --dart-define=TRINEX_FIREBASE_API_KEY=YOUR_API_KEY \
   --dart-define=TRINEX_FIREBASE_APP_ID=YOUR_ANDROID_APP_ID \
   --dart-define=TRINEX_FIREBASE_SENDER_ID=YOUR_SENDER_ID \
   --dart-define=TRINEX_FIREBASE_PROJECT_ID=YOUR_PROJECT_ID
   ```

   Optionally set `TRINEX_FIREBASE_STORAGE_BUCKET`. The service intentionally stays disabled when the required values are missing, so normal login/startup continues to work. If you use `google-services.json`, place it at `apps/student/android/app/google-services.json`; the Gradle plugin is applied only when that file exists. Do not commit service-account JSON or other server credentials.
6. Build and install on a real Android device, sign in with a registered student, accept notification permission, and verify an active row appears in `notification_devices`. Then publish a test announcement and verify the queued push reaches the device while the app is backgrounded. Also test token refresh, logout deactivation, denied permission, and missing Firebase configuration. Do not claim production push delivery is active until these real-device checks and Worker deployment are complete.

## Delivery behavior

- Queue processing is bounded to 40 push rows per minute.
- Transient failures are retried with exponential delay, capped at 60 minutes; a row is marked failed after eight attempts.
- Invalid/unregistered device tokens are deactivated to avoid repeated sends.
- The dispatcher never logs device tokens or service-account credentials.
- In-app notifications remain available through the existing authenticated API, independently of FCM delivery.

## Flutter lifecycle included in the client

- On login and app startup, the app initializes Firebase only when required client values are supplied and a student session exists.
- Android notification permission is requested through Firebase Messaging.
- The current FCM token and refreshed tokens are registered through the authenticated `/api/v1/student/notifications/device` endpoint.
- On logout, the token is deactivated through the authenticated `DELETE /api/v1/student/notifications/device` endpoint before local credentials are cleared.
- Push setup is best-effort and does not block login. Foreground push messages are not yet surfaced as system banners; use the in-app notification inbox while foregrounded.
