-- PulseClass v0.4: one teacher account; students join as anonymous class participants.
-- Non-destructive: preserves existing teacher profiles, classes, sessions and legacy readings.
create table if not exists public.class_participants (
  id uuid primary key default gen_random_uuid(),
  class_id uuid not null references public.classes(id) on delete cascade,
  display_name text not null check (char_length(display_name) between 1 and 60),
  token_hash bytea not null unique,
  joined_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  unique(class_id, id)
);
create index if not exists class_participants_class_idx on public.class_participants(class_id, joined_at);

create table if not exists public.participant_readings (
  id bigint generated always as identity primary key,
  participant_id uuid not null references public.class_participants(id) on delete cascade,
  class_id uuid not null references public.classes(id) on delete cascade,
  session_id uuid not null references public.sessions(id) on delete cascade,
  bpm smallint not null check (bpm between 25 and 250),
  device_name text not null default 'Bluetooth HR monitor',
  recorded_at timestamptz not null default now()
);
create index if not exists participant_readings_session_time_idx on public.participant_readings(session_id, recorded_at desc);
create index if not exists participant_readings_participant_time_idx on public.participant_readings(participant_id, recorded_at desc);

alter table public.class_participants enable row level security;
alter table public.participant_readings enable row level security;
drop policy if exists "teacher reads class participants" on public.class_participants;
create policy "teacher reads class participants" on public.class_participants for select to authenticated using (public.is_teacher_of_class(class_id));
drop policy if exists "teacher reads participant readings" on public.participant_readings;
create policy "teacher reads participant readings" on public.participant_readings for select to authenticated using (public.is_teacher_of_class(class_id));
grant select on public.class_participants, public.participant_readings to authenticated;
revoke all on public.class_participants, public.participant_readings from anon, public;

-- One-time owner bootstrap: if no teacher profile exists yet, the first Auth user
-- becomes the sole teacher. Once a teacher exists, every subsequent signup is rejected.
-- Create that first Auth user from the private Supabase Dashboard before publishing the site,
-- then disable signups in Supabase Auth settings as a second control.
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path=public as $$
begin
  perform pg_advisory_xact_lock(hashtext('pulseclass_single_teacher_bootstrap'));
  if exists (select 1 from public.profiles where role='teacher') then
    raise exception 'PulseClass already has its teacher account. Public account creation is disabled.';
  end if;
  insert into public.profiles(id,full_name,role,age)
  values(new.id,coalesce(nullif(trim(new.raw_user_meta_data->>'full_name'),''),'PulseClass Teacher'),'teacher',null);
  return new;
end $$;

create or replace function public.join_class_anonymous(p_join_code text, p_name text, p_token text)
returns jsonb language plpgsql security definer set search_path=public as $$
declare c public.classes%rowtype; p public.class_participants%rowtype;
begin
  if p_token is null or length(p_token) < 32 or length(p_token) > 128 then raise exception 'Invalid participant token'; end if;
  if p_name is null or char_length(trim(p_name)) < 1 or char_length(trim(p_name)) > 60 then raise exception 'Enter a name (maximum 60 characters)'; end if;
  select * into c from public.classes where join_code=upper(trim(p_join_code));
  if c.id is null then raise exception 'Invalid class code'; end if;
  select * into p from public.class_participants where token_hash=digest(p_token,'sha256');
  if p.id is not null then
    if p.class_id <> c.id then raise exception 'This device is already registered to another class. Clear app data to join a different class.'; end if;
    update public.class_participants set display_name=trim(p_name),last_seen_at=now() where id=p.id;
  else
    insert into public.class_participants(class_id,display_name,token_hash) values(c.id,trim(p_name),digest(p_token,'sha256')) returning * into p;
  end if;
  return jsonb_build_object('participant_id',p.id,'class_id',c.id,'class_name',c.name);
end $$;

create or replace function public.participant_status(p_token text)
returns jsonb language plpgsql security definer set search_path=public as $$
declare p public.class_participants%rowtype; s public.sessions%rowtype; c public.classes%rowtype;
begin
  select * into p from public.class_participants where token_hash=digest(p_token,'sha256');
  if p.id is null then raise exception 'Participant not found. Join your class again.'; end if;
  update public.class_participants set last_seen_at=now() where id=p.id;
  select * into c from public.classes where id=p.class_id;
  select * into s from public.sessions where class_id=p.class_id and ended_at is null order by started_at desc limit 1;
  return jsonb_build_object('participant_id',p.id,'class_id',p.class_id,'class_name',c.name,
    'session',case when s.id is null then null else jsonb_build_object('id',s.id,'lesson_title',s.lesson_title,'target_zone',s.target_zone,'started_at',s.started_at,'planned_duration_minutes',s.planned_duration_minutes) end);
end $$;

create or replace function public.post_participant_reading(p_token text,p_bpm integer,p_device_name text default 'Bluetooth HR monitor')
returns void language plpgsql security definer set search_path=public as $$
declare p public.class_participants%rowtype; s public.sessions%rowtype; last_time timestamptz;
begin
  if p_bpm < 25 or p_bpm > 250 then raise exception 'Heart rate outside accepted range'; end if;
  select * into p from public.class_participants where token_hash=digest(p_token,'sha256');
  if p.id is null then raise exception 'Participant not found. Join your class again.'; end if;
  select * into s from public.sessions where class_id=p.class_id and ended_at is null order by started_at desc limit 1;
  if s.id is null then raise exception 'Your teacher has not opened a lesson'; end if;
  select max(recorded_at) into last_time from public.participant_readings where participant_id=p.id and session_id=s.id;
  if last_time is not null and now() < last_time + interval '1.5 seconds' then return; end if;
  insert into public.participant_readings(participant_id,class_id,session_id,bpm,device_name)
  values(p.id,p.class_id,s.id,p_bpm,left(coalesce(p_device_name,'Bluetooth HR monitor'),80));
  update public.class_participants set last_seen_at=now() where id=p.id;
end $$;

grant execute on function public.join_class_anonymous(text,text,text) to anon, authenticated;
grant execute on function public.participant_status(text) to anon, authenticated;
grant execute on function public.post_participant_reading(text,integer,text) to anon, authenticated;

-- Realtime is used by the authenticated teacher dashboard. Ignore if already published.
do $$ begin
  alter publication supabase_realtime add table public.participant_readings;
exception when duplicate_object then null; when undefined_object then null; end $$;

-- Existing profiles and class data are retained. Do not run public signup from the client.
