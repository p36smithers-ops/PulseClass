# PulseClass build roadmap

## Product decisions

- One teacher account.
- Students join without creating a Supabase Auth account.
- Student access is temporary and scoped to a lesson.
- Mobile app target: iOS and Android, with web preview support.
- Existing Supabase data and tables must be preserved.

## Implemented in this scaffold

- Recovered v0.4 teacher website (`app/index.html`) and native BLE student app (`mobile/`).
- Expo / React Native TypeScript native student app in `mobile/`.
- Teacher sign-in screen using Supabase Auth.
- Mobile session persistence through Expo SecureStore.
- Teacher class listing scoped to the signed-in teacher.
- Class creation through the existing `create_class(p_name)` database function.
- Start and end lesson sessions through the existing `sessions` table.
- Student name + class-code interface wired to the secure `student-access` Edge Function source.
- Native student bearer token stored with Expo SecureStore; browser fallback token stored in sessionStorage.
- Per-lesson participant schema and rate-limit proposal; not yet applied.
- GitHub Actions TypeScript validation workflow.

## Next engineering stages

1. Recover and review the earlier v0.4 project archive. It is retained in the repository; do not overwrite or discard it.
2. Verify package versions, compile and run the Expo app.
3. Review the existing live schema and the archived SQL migrations side by side. Do not replay archived migrations on the connected database without a drift review.
4. Replace the archived class-level participant model with a per-lesson temporary-student identity model. The existing `class_memberships` table references `profiles`, which references `auth.users`; it cannot directly represent students without Auth accounts.
5. Test and review the new `student-access` Edge Function and `002_secure_per_lesson_students.sql` proposal against a disposable database; only then deploy/apply with explicit approval.
6. The Edge Function source now validates the token, session, class, BPM range and sampling interval; verify it end-to-end after deployment.
7. Add real-time teacher monitoring and session summaries.
8. Test with synthetic readings and a small classroom pilot before collecting real student data.

## Safety and data handling

- Never expose a Supabase secret key in the mobile app or GitHub.
- Never accept a student-supplied class/session/user ID as proof of access.
- Do not treat a display name as authentication.
- Do not collect real heart-rate data until access controls, consent, retention and school safeguarding requirements are reviewed.
- No production schema migration or Edge Function deployment is part of this source scaffold.
