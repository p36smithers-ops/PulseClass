# PulseClass Student mobile app

Native iOS and Android anonymous student sensor collector. The teacher dashboard stays in `../app/` as a website.

## Local setup

1. Install Node.js LTS.
2. Copy `.env.example` to `.env` and add the Supabase URL and public anon/publishable key. Apply database migration `003_single_teacher_anonymous_students.sql`.
3. Run `npm install`.
4. Run `npm run typecheck`. For EAS builds, run `eas build:configure` once, then `eas build --profile preview --platform android` and/or `eas build --profile preview --platform ios`.
5. For signed internal distribution, configure EAS as described in the root README.

## Bluetooth behaviour

- Scans for standard Heart Rate Service UUID `180D`.
- Displays discovered monitors so the student can choose their own device. This matters in a classroom where many sensors broadcast simultaneously.
- Connects to Heart Rate Measurement characteristic `2A37` and decodes 8-bit or 16-bit BPM values.
- Joins a class using a display name and class code; no student email, password or Auth account is created.
- Uses a per-device random participant token, stored locally; the database stores its SHA-256 hash rather than the raw token.
- Samples database writes at a maximum of one per three seconds while an active class lesson exists.
- Keeps the screen awake while connected and instructs students to leave the app foregrounded.
- Does not claim background BLE collection, offline replay or compatibility with devices that do not expose the standard service.

## Configuration and secrets

`EXPO_PUBLIC_` environment values are bundled into the app. Use only the Supabase public anon/publishable key; never put a service-role key in this app. Security must be enforced with Supabase RLS and server-side validation.
