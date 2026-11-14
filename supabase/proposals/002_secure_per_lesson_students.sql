-- PROPOSAL ONLY. Do not apply to the live project until reviewed and tested.
-- This replaces the archived class-scoped anonymous participant design with
-- one short-lived participant identity per active lesson.
begin;

-- The recovered teacher dashboard and status endpoint use these fields.
alter table public.sessions
  add column if not exists lesson_title text not null default 'Sports science lesson',
  add column if not exists target_zone smallint not null default 3
    check (target_zone between 1 and 5),
  add column if not exists planned_duration_minutes smallint not null default 30
    check (planned_duration_minutes between 1 and 240);

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.sessions'::regclass
      and conname = 'sessions_id_class_id_key'
  ) then
    alter table public.sessions
      add constraint sessions_id_class_id_key unique (id, class_id);
  end if;
end $$;

-- The teacher UI already prevents concurrent lessons per class; enforce it in
-- the database as well.
create unique index if not exists sessions_one_active_per_class_idx
  on public.sessions (class_id)
  where ended_at is null;

create table public.lesson_participants (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null,
  class_id uuid not null,
  display_name text not null
    check (char_length(btrim(display_name)) between 1 and 60),
  token_hash text not null unique
    check (token_hash ~ '^[a-f0-9]{64}$'),
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  last_reading_at timestamptz,
  expires_at timestamptz not null default (now() + interval '8 hours'),
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
  on public.lesson_participants (session_id, created_at);
create index lesson_participants_active_expiry_idx
  on public.lesson_participants (expires_at)
  where revoked_at is null;

create table public.participant_readings (
  id bigint generated always as identity primary key,
  participant_id uuid not null,
  session_id uuid not null,
  class_id uuid not null,
  bpm smallint not null check (bpm between 25 and 250),
  device_name text not null default 'Bluetooth HR monitor'
    check (char_length(device_name) <= 80),
  recorded_at timestamptz not null default now(),
  constraint participant_readings_participant_binding_fkey
    foreign key (participant_id, session_id, class_id)
    references public.lesson_participants (id, session_id, class_id)
    on delete cascade
);
create index participant_readings_session_time_idx
  on public.participant_readings (session_id, recorded_at desc);
create index participant_readings_participant_time_idx
  on public.participant_readings (participant_id, recorded_at desc);

-- Rate-limit join-code attempts using an HMAC of the client IP. The raw IP is
-- never stored. Only the server-side Edge Function may call this function.
create table public.join_attempts (
  ip_hash text primary key check (ip_hash ~ '^[a-f0-9]{64}$'),
  window_started_at timestamptz not null default now(),
  attempt_count smallint not null default 0,
  blocked_until timestamptz
);
alter table public.join_attempts enable row level security;
revoke all on table public.join_attempts from public, anon, authenticated;
grant all on table public.join_attempts to service_role;

create or replace function public.consume_join_attempt(p_ip_hash text)
returns boolean
language plpgsql
security definer
set search_path = public
as $function$
declare v public.join_attempts%rowtype;
begin
  if p_ip_hash is null or p_ip_hash !~ '^[a-f0-9]{64}$' then
    return false;
  end if;

  perform pg_advisory_xact_lock(hashtext(p_ip_hash));
  select * into v
  from public.join_attempts
  where ip_hash = p_ip_hash
  for update;

  if not found then
    insert into public.join_attempts(ip_hash, attempt_count)
    values (p_ip_hash, 1);
    return true;
  end if;

  if v.blocked_until is not null and v.blocked_until > now() then
    return false;
  end if;

  if v.window_started_at < now() - interval '10 minutes'
     or (v.blocked_until is not null and v.blocked_until <= now()) then
    update public.join_attempts
      set window_started_at = now(), attempt_count = 1, blocked_until = null
      where ip_hash = p_ip_hash;
    return true;
  end if;

  if v.attempt_count >= 9 then
    update public.join_attempts
      set attempt_count = attempt_count + 1,
          blocked_until = now() + interval '15 minutes'
      where ip_hash = p_ip_hash;
    return false;
  end if;

  update public.join_attempts
    set attempt_count = attempt_count + 1
    where ip_hash = p_ip_hash;
  return true;
end
$function$;

revoke all on function public.consume_join_attempt(text) from public, anon, authenticated;
grant execute on function public.consume_join_attempt(text) to service_role;

-- A lesson end invalidates every participant token for that lesson.
create or replace function public.revoke_lesson_participants_on_end()
returns trigger
language plpgsql
security definer
set search_path = public
as $function$
begin
  if old.ended_at is null and new.ended_at is not null then
    update public.lesson_participants
      set revoked_at = now()
      where session_id = new.id and revoked_at is null;
  end if;
  return new;
end
$function$;

drop trigger if exists revoke_lesson_participants_on_end on public.sessions;
create trigger revoke_lesson_participants_on_end
after update of ended_at on public.sessions
for each row execute function public.revoke_lesson_participants_on_end();

alter table public.lesson_participants enable row level security;
alter table public.participant_readings enable row level security;

revoke all on table public.lesson_participants from public, anon, authenticated;
revoke all on table public.participant_readings from public, anon, authenticated;
grant select (id, session_id, class_id, display_name, created_at, last_seen_at, expires_at, revoked_at)
  on public.lesson_participants to authenticated;
grant select on public.participant_readings to authenticated;
grant all on table public.lesson_participants, public.participant_readings to service_role;
grant usage, select on sequence public.participant_readings_id_seq to service_role;

drop policy if exists "teachers read lesson participants" on public.lesson_participants;
create policy "teachers read lesson participants"
  on public.lesson_participants for select to authenticated
  using (public.is_teacher_of_class(class_id));

drop policy if exists "teachers read participant readings" on public.participant_readings;
create policy "teachers read participant readings"
  on public.participant_readings for select to authenticated
  using (public.is_teacher_of_class(class_id));

-- Longer, harder-to-guess class codes for newly created classes.
create or replace function public.create_class(p_name text)
returns uuid
language plpgsql
security definer
set search_path = public
as $function$
declare new_id uuid; code text;
begin
  if (select role from public.profiles where id = auth.uid()) <> 'teacher' then
    raise exception 'Teacher account required';
  end if;
  code := upper(encode(gen_random_bytes(6), 'hex'));
  insert into public.classes(name, join_code, teacher_id)
    values (trim(p_name), code, auth.uid())
    returning id into new_id;
  return new_id;
end
$function$;

-- Single teacher bootstrap: the first Auth user becomes the teacher; no
-- user_metadata role can grant teacher permissions. Later account creation
-- is rejected by the trigger. Public Auth signups must also be disabled.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $function$
begin
  perform pg_advisory_xact_lock(hashtext('pulseclass_single_teacher_bootstrap'));
  if exists (select 1 from public.profiles where role = 'teacher') then
    raise exception 'PulseClass already has its teacher account. Public account creation is disabled.';
  end if;
  insert into public.profiles(id, full_name, role, age)
    values (new.id, 'PulseClass Teacher', 'teacher', null);
  return new;
end
$function$;

-- Narrow function execution grants. SECURITY DEFINER functions are not
-- executable by PUBLIC, and student join/reading requests go only through
-- the Edge Function.
revoke all on function public.handle_new_user() from public, anon, authenticated;
revoke all on function public.create_class(text) from public, anon;
revoke all on function public.join_class(text) from public, anon, authenticated;
revoke all on function public.is_teacher_of_class(uuid, uuid) from public, anon;
revoke all on function public.is_member_of_class(uuid, uuid) from public, anon;
revoke all on function public.can_view_profile(uuid) from public, anon;

grant execute on function public.create_class(text) to authenticated;
grant execute on function public.is_teacher_of_class(uuid, uuid) to authenticated;
grant execute on function public.is_member_of_class(uuid, uuid) to authenticated;
grant execute on function public.can_view_profile(uuid) to authenticated;

do $$
begin
  alter publication supabase_realtime add table public.participant_readings;
exception when duplicate_object then null;
end $$;

commit;

-- Deploy supabase/functions/student-access/index.ts only after this proposal
-- has been tested against a disposable copy of the connected live schema.
-- Deploy that Edge Function with verify_jwt=false; its body validates the
-- publishable key, rate-limits join attempts, and uses the server-only secret.
