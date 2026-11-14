# Review of the archived v0.4 project against the connected live database

This review was performed after unpacking the original ZIP. It is a source review only. No database changes, account changes, Edge Function deployments or production migrations have been made.

## What was recovered

- Teacher dashboard and student browser fallback: `app/index.html`
- Native iOS/Android BLE student app: `mobile/src/App.tsx`
- Fresh-install schema: `supabase/schema.sql`
- Earlier and anonymous-student migrations: `supabase/migrations/002_native_student_app.sql` and `003_single_teacher_anonymous_students.sql`
- Device compatibility and classroom pilot documentation.

## Compatibility issue with the connected live database

The live `public.sessions` table currently has only `id, class_id, created_by, started_at, ended_at`. The archived website and migration 003 expect three additional columns:
- `lesson_title`
- `target_zone`
- `planned_duration_minutes`

The fresh-install `schema.sql` defines these columns, but migration 003 does not add them. Therefore the archived migration cannot be applied as-is to the connected project, and the teacher website's session insert / student status response would fail against the current live schema.

## Security and product gaps to resolve before student data is collected

1. **Student identity lifetime:** archived `class_participants` are class-scoped and persist across lessons. The agreed product model is temporary per-lesson identity. A participant must be tied to one active session and be expired/revoked when that session ends.
2. **Token lifetime:** migration 003 stores a SHA-256 token hash, which is good, but has no expiry or revocation fields. A lost device token remains valid indefinitely.
3. **Join-code guessing:** `join_class_anonymous` has no rate limit or lockout. Join codes need stronger entropy and a server-side attempt limit.
4. **Function grants:** new SECURITY DEFINER RPCs are granted to anon/authenticated, but the default PUBLIC execute grant should be explicitly revoked and only the required roles re-granted. Existing SECURITY DEFINER function grants in the live database also need a complete review.
5. **Session binding:** `post_participant_reading` finds the current active session by class rather than validating a participant token that is bound to a specific session. This does not meet the agreed per-lesson identity model.
6. **Age/zone calculation:** both archived dashboards use age 16 for every student when estimating HR zones. This is not individually accurate and must not be used for assessment or safety decisions. Either collect an optional, justified age value with school approval or remove personalized zone claims.
7. **Token storage:** the original native app used AsyncStorage. The source has now been updated to use Expo SecureStore; the web fallback uses sessionStorage for its participant token.
8. **Hardware testing:** BLE code is a starting implementation. WHOOP, each intended Garmin model and chest straps still need hands-on testing on real iOS and Android devices.

## Current live database facts

- Existing tables are present and empty.
- RLS is enabled on all five existing public tables.
- There are no Auth users yet.
- No Edge Functions are deployed.
- The existing heart-rate INSERT policy previously contained a tautological session/class comparison; migration 002 includes a corrected policy, but it has not been applied.

## Safe next steps

1. Draft a new incremental migration that matches the live schema and implements per-session temporary participants, token expiry/revocation, and a safe join-rate limit.
2. Review all SECURITY DEFINER grants and RLS policies.
3. Test the migration and RPC/Edge Function flows against a disposable database.
4. Only then request approval to apply the migration to the connected project.
5. Connect the recovered website and native app to the tested backend and run synthetic-data tests before a supervised hardware pilot.
