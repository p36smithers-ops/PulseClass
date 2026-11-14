# PulseClass — single-teacher classroom build (v0.4)

PulseClass is structured as a **single-teacher web dashboard + anonymous student join flow + native iOS/Android student sensor app**. This is the recommended arrangement for a class of 20–30 students using a mixture of iPhones and Android phones, WHOOP bands, compatible Garmin watches and Bluetooth LE chest straps.

> This is source code and a deployment package, not a hosted service or signed App Store / Play Store release. It still needs a school Supabase project, hosting, mobile builds, device testing and school approval.

## What's in this version

- `app/`: browser-based teacher dashboard and student web fallback.
- `mobile/`: Expo / React Native student app for iOS and Android, using native Bluetooth LE rather than Web Bluetooth.
- `supabase/schema.sql`: fresh-install database schema, authentication, roles, class codes, lessons, heart-rate readings and row-level security.
- `supabase/migrations/002_native_student_app.sql`: earlier native-app migration.
- `supabase/migrations/003_single_teacher_anonymous_students.sql`: archived v0.4 migration draft. It is **not approved for direct application**; see `docs/legacy-v04-review.md`.
- `docs/`: deployment, device compatibility and pilot acceptance guidance.

## Recommended classroom architecture

1. Teacher uses the web dashboard on a laptop connected to the school network.
2. Teacher opens a lesson and shares its class code.
3. Each student opens the student app on their iPhone or Android phone, enters their name and class code (no signup or login), and connects one heart-rate device.
4. The mobile app reads the standard Bluetooth LE Heart Rate Service (GATT service `180D`, measurement characteristic `2A37`) using native Bluetooth APIs.
5. Each student phone writes a reading to Supabase approximately every three seconds while a lesson is active.
6. Supabase Postgres stores the readings; Supabase Realtime sends inserts to the teacher's class dashboard.
7. Teacher ends the lesson and reviews the stored report.

For 20–30 students this is a modest workload: approximately 7–10 readings/second across the class at the configured sampling interval, with one or a small number of teacher dashboards subscribed. The existing Postgres Changes approach is suitable for this initial scale; benchmark it with the school's actual Wi-Fi and account plan before increasing the class size. Supabase recommends Broadcast for much larger fan-out workloads.

## Device support strategy

PulseClass does not depend on brand-specific cloud APIs for live HR. It listens for the standard Bluetooth LE Heart Rate Service, which avoids the delay and account/API limitations of cloud-sync integrations.

- **WHOOP:** student enables Heart Rate Broadcast in WHOOP Device Settings, then pairs the broadcast from PulseClass. WHOOP's support material documents this broadcast feature. If the band is already streaming to another receiver, disconnect that receiver and retry.
- **Garmin watches:** only models with Bluetooth Broadcast Heart Rate are supported. The student must enable Broadcast Heart Rate on the watch before scanning. Check Garmin's current compatibility list and the specific watch manual; not every Garmin model broadcasts over Bluetooth.
- **Chest straps:** Polar, Wahoo, Garmin and other straps should work if they expose the standard BLE Heart Rate Service. ANT+-only devices and proprietary-only sensors will not work through this BLE route.
- **Unknown / mixed devices:** ask the student to enable broadcast mode and run the in-app scan. A device that does not advertise the standard service cannot be assumed compatible. Record the exact make/model during the pilot.
- **Apple Watch:** not supported as a direct BLE heart-rate peripheral in this build. It requires a separate iOS HealthKit companion workflow and should be treated as a later integration, not promised for this pilot.
- **Fitbit:** not included in the direct BLE compatibility promise. Specific models and broadcast support vary; do not assume compatibility without a device-level test.

### Why the native student app matters

Web Bluetooth is not available in iOS Safari and browser support is not universal. The native companion app uses CoreBluetooth on iOS and Android BLE APIs through `react-native-ble-plx`, so mixed iPhone/Android classrooms can use one student workflow. The teacher dashboard remains a normal website. Keep the student app open in the foreground during lessons; this release deliberately does not claim background BLE collection.

## Deployment steps

### A. Set up Supabase

1. Create a Supabase project in a region approved by the school. For an Irish school, discuss EU data residency with the school's data-protection lead before selecting the region.
2. Treat `supabase/schema.sql` as a fresh-install reference only. Do not run it against the connected PulseClass project.
3. Do **not** apply migrations 002 or 003 to the connected project yet. The archived 003 migration expects session columns that are missing from the live schema, and its anonymous-student token model needs expiry, revocation and join-rate limiting. See `docs/legacy-v04-review.md`.
4. In Database → Publications, confirm `participant_readings` is included in `supabase_realtime` (the migration attempts to add it automatically).
5. The connected project currently has no Auth users. Provision the single teacher account only after the reviewed migration and account-bootstrap plan are ready. Do not enable public signups.
6. Keep the Supabase service-role key private. The web app and mobile app use only the public anon/publishable key with RLS enabled.
7. Confirm the single owner teacher profile with this read-only query:

   ```sql
   select id, full_name, role from public.profiles where role = 'teacher';
   ```

   If no teacher profile exists yet, create the first Auth user from the private Supabase Dashboard before publishing the site; the trigger assigns that first account the teacher role. Existing legacy student accounts are not deleted by the migration, to avoid destructive data loss. New student participation uses `class_participants` and `participant_readings`.

### B. Deploy the teacher website

1. Deploy the contents of `app/` to a static HTTPS host (for example, the school's approved Vercel, Netlify or Cloudflare Pages account).
2. Open the site and enter the Supabase project URL and public anon/publishable key.
3. Sign in with your existing teacher account, create a class and check that the class code appears. Students join with their name and the code; no student account is created.
4. Keep the teacher dashboard open on a laptop or desktop browser during the lesson.

### C. Build the student mobile app

Requirements: Node.js LTS, an Apple Developer account for iOS device distribution, and the relevant Android signing / Play Console or managed-device distribution access.

1. Open a terminal in `mobile/`.
2. Copy `.env.example` to `.env` and set:

   ```env
   EXPO_PUBLIC_SUPABASE_URL=https://YOUR_PROJECT.supabase.co
   EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLIC_PUBLISHABLE_KEY
   ```

3. Install dependencies: `npm install`.
4. Install EAS CLI and sign in: `npm install -g eas-cli` then `eas login`.
5. Run `eas build:configure` once to create the EAS project and populate the project ID in `app.json`.
6. Build Android internal test: `eas build --profile preview --platform android`.
7. Build iOS internal test: `eas build --profile preview --platform ios`.
8. Install the test builds on representative student phones. For iOS, add testers through TestFlight or an approved school distribution route; for Android, use internal testing or managed Google Play.
9. Once the pilot passes, create production builds with `eas build --profile production --platform all` and complete the school's chosen distribution / store review process.

Do not distribute an unsigned development build as a classroom-ready app. Keep `.env` out of source control. The `EXPO_PUBLIC_` values are public client configuration, not secrets; RLS and auth are the security boundary.

### D. Run a classroom pilot

Use 4–6 students first: at least one iPhone, one Android phone, one WHOOP, one Garmin model, and one BLE chest strap if available. Test each device for 10 minutes before scaling to 20–30. Use `docs/classroom-pilot.md` as the acceptance checklist.

## Security and school readiness still required

- Complete the school's GDPR / data-protection review, DPIA where required, lawful-basis and consent/guardian arrangements, student notice, retention schedule, deletion process and incident process.
- Confirm the school's rules for collecting student heart-rate data and for using personal phones / wearables in PE.
- Use verified teacher accounts; do not expose admin credentials or service-role keys.
- Review and penetration-test RLS with teacher, student, unrelated student and unauthenticated accounts. The current schema is a starting point, not a formal security audit.
- Configure backups, monitoring, email delivery, project spend limits and operational ownership.
- Establish how students without a compatible phone or wearable participate; do not make wearable ownership a barrier to lesson participation or assessment.
- Confirm teacher reports are educational estimates, not medical or diagnostic outputs.

## Measurement notes

- HRmax currently uses the estimate `208 − 0.7 × age` and five broad zones. This is not an individually measured maximum and should not be used as a medical threshold.
- Readings are sampled to the database about every three seconds. Time-in-zone is estimated between adjacent readings and long gaps are excluded. It is not exact physiological time in zone.
- The mobile app is foreground-only in this release. Screen-awake support is enabled while connected. Do not promise collection after the student backgrounds or force-quits the app.
- If a phone loses internet, readings are not guaranteed to be uploaded later. A live lesson requires a working network path from each student phone to Supabase.

## Operational troubleshooting

- **No sensor appears:** confirm battery, wear / wake the strap, enable WHOOP or Garmin broadcast, ensure the device supports Bluetooth HR broadcast, disconnect any other receiver and scan again.
- **Sensor connects but no BPM:** confirm it exposes Heart Rate Measurement (`2A37`) under Heart Rate Service (`180D`), wear it correctly and check its firmware.
- **iPhone cannot scan from website:** use the native PulseClass Student app; iOS Safari does not provide Web Bluetooth.
- **Readings stop:** keep app foregrounded, screen awake, Bluetooth enabled and network connected. Reconnect the sensor and check the teacher dashboard's last-reading status.
- **Teacher sees stale student:** check the student's app status, phone internet and active lesson. Stale readings should not be interpreted as zero HR.

## v0.4 source package — integration and security review pending

This release changes the student identity model. The teacher signs in with the existing Supabase Auth account. Students do **not** sign up, sign in, or create Supabase Auth users: they enter a display name and the class join code, then the client creates a random per-device participant token. The database stores only a SHA-256 hash of that token. Student readings are written through a rate-limited RPC into `participant_readings`; the teacher dashboard reads the participant roster and readings under teacher-only RLS policies.

### Upgrade an existing Supabase project

1. Back up the project before changing its schema.
2. Do not run the archived migration 003 directly. The connected live schema differs from the fresh-install schema and the anonymous participant token model needs hardening. Follow `docs/legacy-v04-review.md` and wait for a reviewed incremental migration.
3. Confirm your existing teacher can still sign in and open the dashboard.
4. Do not run the fresh-project `schema.sql` over an existing database. The migration is designed to preserve existing classes, sessions, profiles and historical readings.
5. The database trigger permits a one-time first-teacher bootstrap only when no teacher profile exists. Create that user privately in the Supabase Dashboard before publishing, then disable public signups in Auth settings. Never expose a service-role key in either client.

### Website deployment

Host the contents of `app/` as a static site on an HTTPS host (for example, Netlify, Vercel or Cloudflare Pages). Open the site, enter the Supabase project URL and the public anon/publishable key, then connect. Students use the same page and select the student join area; teacher sign-in is retained for the owner. Browser Bluetooth requires a supported Chromium browser; iOS students should use the native app.

### Native app build

1. Copy `mobile/.env.example` to `mobile/.env` and fill in the Supabase project URL and **public anon/publishable** key. Never use the service-role key.
2. Install dependencies from `mobile/` with `npm install`.
3. Run `npm run typecheck`.
4. Install/configure EAS CLI, sign in to the Expo account, and run `eas build:configure` once to create and populate the EAS project ID in `mobile/app.json`.
5. Run `npm run build:android` and `npm run build:ios` (iOS builds require the appropriate Apple developer signing setup).

### Important limitations and data protection

- The student participant token is a bearer credential stored using device secure storage in the native app and session storage in the browser fallback. Do not share it. Server-side expiry and revocation still need to be implemented before real student data is collected.
- Students can join any class if they know its code. Treat class codes as private and rotate/recreate classes if a code is shared beyond the class.
- Existing student Auth users and legacy membership/readings are not deleted by this migration. They are retained to avoid destructive data loss; new student participation uses the anonymous participant tables. Delete legacy accounts/data only after reviewing retention obligations and explicitly approving that cleanup.
- Native BLE collection is foreground-only. The app has not been tested with physical WHOOP/Garmin/chest-strap hardware or in a live classroom. Conduct a supervised pilot before relying on it.
- HR data is sensitive student data. Confirm lawful basis/consent, school policy, access controls and retention/deletion rules before collecting real student readings.


---

## Repository notes

The original v0.4 source archive has been unpacked into `app/`, `mobile/`, `supabase/`, and `docs/`. The intended product surfaces are the teacher website in `app/` and the student BLE companion in `mobile/`. Archived SQL files are retained for review only and have not been applied to the connected database.
