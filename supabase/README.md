# Supabase integration notes

This folder documents the application-side Supabase setup. The connected project already has a live schema and RLS policies, so do not apply a guessed baseline migration or replace existing tables.

## Current live schema (audited)

- `profiles` is linked to `auth.users`; teacher accounts are provisioned through Supabase Auth.
- `classes` are owned by the teacher profile and have unique join codes.
- `sessions` belong to classes.
- `heart_rate_readings` are linked to sessions, classes and profiles.
- `class_memberships` currently references profiles and therefore does not support the intended no-student-auth workflow by itself.

## Current app integration

- The mobile client uses the publishable/anon key only.
- Teacher authentication uses email/password and persists sessions using Expo SecureStore.
- Class listing uses the existing RLS policies.
- Class creation calls the existing `create_class(p_name)` RPC.

## Required before enabling student joining

The intended student experience is display name + class code, without student Supabase Auth accounts. Do not reuse `join_class` as-is: it requires an authenticated student profile.

A reviewed incremental schema design is required for short-lived lesson identities and hashed, revocable join tokens. The Edge Function must validate the class code, active session, expiry, token binding and request rate before writing any readings. Keep the secret key server-side. Never ship it in the app.

## Known integrity fix to review

The current heart-rate INSERT policy contains a tautological session/class comparison (`s.class_id = s.class_id`). Before accepting readings, replace it with a check that the selected session's class matches the submitted reading class. Review all function grants and RLS policies as part of the same security pass.

## Deployment status

No production migrations, Edge Functions, account provisioning or policy changes have been performed by this scaffold.
