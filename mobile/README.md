# PulseClass Student mobile app

Native iOS and Android anonymous student sensor collector. The teacher dashboard stays in `../app/` as a website.

## Local setup

1. Install Node.js LTS.
2. Copy `.env.example` to `.env` and add the Supabase URL and public anon/publishable key. Do not apply archived migration 003 until the live-schema compatibility and security review in `../docs/legacy-v04-review.md` is complete.
3. Run `npm install`.
4. Run `npm run typecheck`. For EAS builds, run `eas build:configure` once, then `eas build --profile preview --platform android` and/or `eas build --profile preview --platform ios`.
5. For signed internal distribution, configure EAS as described in the root README.

## Bluetooth behaviour

- Scans for standard Heart Rate Service UUID `180D`.
- Displays discovered monitors so the student can choose their own device. This matters in a classroom where many sensors broadcast simultaneously.
- Connects to Heart Rate Measurement characteristic `2A37` and decodes 8-bit or 16-bit BPM values.
- Joins a class using a display name and class code; no student email, password or Auth account is created.
- Uses a fresh random participant token for each lesson, stored with Expo SecureStore; the database stores only its SHA-256 hash. Join, status and readings go through the `student-access` Edge Function.
- Samples database writes at a maximum of one per three seconds while an active lesson exists; the server enforces the session binding, token expiry/revocation and write interval.
- Keeps the screen awake while connected and instructs students to leave the app foregrounded.
- Does not claim background BLE collection, offline replay or compatibility with devices that do not expose the standard service.

## Configuration and secrets

`EXPO_PUBLIC_` environment values are bundled into the app. Use only the Supabase public anon/publishable key; never put a service-role key in this app. Security is enforced by RLS for teacher reads and server-side validation for student writes; the Edge Function's secret key is never included in the app.
