# Temporary student access design (proposal only)

This is a design note, not a migration. Nothing in this file has been applied to the live database.

## Why a separate participant model is needed

The current schema has `class_memberships.user_id -> profiles.id -> auth.users.id`. That relationship cannot represent a student who has no Supabase Auth account. The current `join_class(p_join_code)` function also expects an authenticated student profile, so the mobile app must not call it for the new student flow.

## Proposed model

Use a `public.lesson_participants` table with one row per student per lesson. Enable RLS, revoke all access from `anon`, and revoke all write access from `authenticated`. Give the authenticated teacher read-only access to non-secret participant columns through a teacher-only policy. Only trusted server-side code may read or write token hashes.
- `id uuid primary key default gen_random_uuid()`
- `session_id uuid not null references sessions(id) on delete cascade` (the participant belongs to exactly one lesson)
- `class_id uuid not null references classes(id) on delete cascade`
- `display_name text not null` (length-limited and normalized)
- `token_hash text not null unique` (hash of a cryptographically random opaque token; never store the raw token)
- `created_at timestamptz not null default now()`
- `expires_at timestamptz not null`
- `revoked_at timestamptz null`

Keep the existing `heart_rate_readings` table unchanged for legacy authenticated users. Add a separate `participant_readings` table with `participant_id`, `class_id`, `session_id`, `bpm`, `device_name` and `recorded_at`. Add a composite foreign key so participant, class and session must match. Give the teacher read-only access through a policy that checks `is_teacher_of_class(class_id)`; student writes happen only through the server-side endpoint.

Keep `lesson_participants` inaccessible to public client roles despite its `public` schema location. Only trusted server-side code should read or write it.

## Join endpoint behaviour

1. Accept only a display name, class join code and an opaque random token generated on the device.
2. Normalize and rate-limit join attempts at a server endpoint before revealing whether a code is valid.
3. Find an active session for the class; do not allow joining a class with no active session.
4. Create a new participant row scoped to that session, with a short expiry, and store only a hash of the random token.
5. Return the raw token once to the student's device. Store it in platform secure storage.
6. Never accept a participant, class, or session ID from the client as proof of permission.

## Reading endpoint behaviour

1. Require the opaque participant token.
2. Hash it and resolve a non-revoked, non-expired participant.
3. Verify the participant's one bound session is still active and class/session bindings agree.
4. Validate BPM (25–250) and a bounded timestamp window.
5. Insert into `participant_readings` with the participant ID and server-verified class/session IDs.
6. Rate-limit writes and return only the minimum response.

## End-of-lesson behaviour

When the teacher ends the session, revoke all participants for that session. Expiry is a second safety net. Tokens should be invalidated on every status and reading request, not just on the student app's local state. A new lesson requires a new participant token and participant row.

## Required migration review

Before applying a migration:
- Re-check nullability, constraints, indexes and RLS on the live database.
- Correct the existing heart-rate INSERT policy's tautological class comparison.
- Review existing SECURITY DEFINER function grants and helper-function use.
- Test the migration against a disposable database seeded from a fresh schema dump.
- Confirm historical readings and teacher workflows remain unchanged.

The archived v0.4 migration instead uses class-scoped `class_participants` that persist across lessons; that model does not satisfy the agreed per-lesson identity requirement. Do not deploy the archived student RPCs until this model and its migration have passed review.
