-- PROPOSAL ONLY — do not apply directly to production.
-- Review and test against a disposable copy of the live schema first.
begin;

-- Ensure a participant's session and class are a valid pair.
alter table public.sessions
  add constraint sessions_id_class_id_key unique (id, class_id);

create table public.lesson_participants (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null,
  class_id uuid not null,
  display_name text not null
    check (char_length(btrim(display_name)) between 1 and 60),
  token_hash text not null unique
    check (token_hash ~ '^[a-f0-9]{64}$'),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  revoked_at timestamptz,
  constraint lesson_participants_expiry_check check (expires_at > created_at),
  constraint lesson_participants_session_class_fkey
    foreign key (session_id, class_id)
    references public.sessions (id, class_id)
    on delete cascade,
  constraint lesson_participants_id_session_class_key
    unique (id, session_id, class_id)
);

create index lesson_participants_session_idx
  on public.lesson_participants (session_id);
create index lesson_participants_active_expiry_idx
  on public.lesson_participants (expires_at)
  where revoked_at is null;

alter table public.lesson_participants enable row level security;
revoke all on table public.lesson_participants from public, anon, authenticated;
grant select, insert, update, delete on table public.lesson_participants to service_role;

-- Preserve existing authenticated-student rows while supporting temporary
-- students who have no auth.users/profiles row.
alter table public.heart_rate_readings
  alter column user_id drop not null;

alter table public.heart_rate_readings
  add column participant_id uuid;

alter table public.heart_rate_readings
  add constraint heart_rate_readings_one_identity_check
  check (num_nonnulls(user_id, participant_id) = 1);

alter table public.heart_rate_readings
  add constraint heart_rate_readings_participant_session_class_fkey
  foreign key (participant_id, session_id, class_id)
  references public.lesson_participants (id, session_id, class_id)
  on delete cascade;

create index heart_rate_readings_participant_idx
  on public.heart_rate_readings (participant_id)
  where participant_id is not null;

-- Correct the existing tautological class comparison. Authenticated legacy
-- students may still insert only their own reading as a member of an active
-- session. Temporary students write only through the server-side Edge Function.
drop policy if exists "students insert own session readings"
  on public.heart_rate_readings;

create policy "students insert own session readings"
  on public.heart_rate_readings
  for insert
  to authenticated
  with check (
    user_id = (select auth.uid())
    and participant_id is null
    and public.is_member_of_class(class_id, (select auth.uid()))
    and exists (
      select 1
      from public.sessions s
      where s.id = heart_rate_readings.session_id
        and s.class_id = heart_rate_readings.class_id
        and s.ended_at is null
    )
  );

commit;

-- Edge Functions must use the server-side secret key to access this table.
-- Never expose the token_hash table or a secret key to the mobile client.
