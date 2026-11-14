# Temporary student access design (proposal only)

This is a design note, not a migration. Nothing in this file has been applied to the live database.

## Why a separate participant model is needed

The current schema has `class_memberships.user_id -> profiles.id -> auth.users.id`. That relationship cannot represent a student who has no Supabase Auth account. The current `join_class(p_join_code)` function also expects an authenticated student profile, so the mobile app must not call it for the new student flow.

## Proposed model

Add a private `lesson_participants` table:
- `id uuid primary key default gen_random_uuid()`
- `session_id uuid not null references sessions(id) on delete cascade`
- `class_id uuid not null references classes(id) on delete cascade`
- `display_name text not null` (length-limited and normalized)
- `token_hash text not null unique` (hash of a cryptographically random opaque token; never store the raw token)
- `created_at timestamptz not null default now()`
- `expires_at timestamptz not null`
- `revoked_at timestamptz null`

Add a nullable `participant_id uuid references lesson_participants(id)` to `heart_rate_readings`. Keep existing `user_id` values intact, but allow it to be null for temporary participants and add a check requiring exactly one identity path: authenticated `user_id` OR temporary `participant_id`. Existing historical readings remain associated with `user_id`.

Keep `lesson_participants` out of public client access. Only trusted server-side code should read or write it.

## Join endpoint behaviour

1. Accept only a display name and class join code.
2. Normalize and rate-limit join attempts before revealing whether a code is valid.
3. Find an active session for the class; do not allow joining a class with no active session.
4. Create a participant record with a short-lived expiry and store only a hash of a random token.
5. Return the raw token once to the student's device. Store it in platform secure storage.
6. Never accept a student, class, or session ID from the client as proof of permission.

## Reading endpoint behaviour

1. Require the opaque participant token.
2. Hash it and resolve a non-revoked, non-expired participant.
3. Verify the participant's session is still active and class/session bindings agree.
4. Validate BPM (25–250) and a bounded timestamp window.
5. Insert the reading with the participant ID and server-verified class/session IDs.
6. Rate-limit writes and return only the minimum response.

## End-of-lesson behaviour

When the teacher ends the session, revoke all participants for that session. Expiry is a second safety net. Tokens should be invalidated on every reading request, not just on the student app's local state.

## Required migration review

Before applying a migration:
- Re-check nullability, constraints, indexes and RLS on the live database.
- Correct the existing heart-rate INSERT policy's tautological class comparison.
- Review existing SECURITY DEFINER function grants and helper-function use.
- Test the migration against a disposable database seeded from a fresh schema dump.
- Confirm historical readings and teacher workflows remain unchanged.

Do not deploy the student endpoint until this model and the migration have passed review.
