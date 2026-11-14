-- Test-only approximation of the audited live PulseClass schema.
-- This is disposable CI data, never applied to the connected Supabase project.
create extension if not exists pgcrypto;
create schema if not exists auth;
create schema if not exists extensions;

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then create role anon nologin; end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then create role authenticated nologin; end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then create role service_role nologin bypassrls; end if;
end $$;

create table auth.users (
  id uuid primary key,
  raw_user_meta_data jsonb not null default '{}'::jsonb
);

create or replace function auth.uid()
returns uuid
language sql stable
as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
$$;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  role text not null check (role in ('teacher', 'student')),
  age smallint check (age between 10 and 100),
  created_at timestamptz not null default now()
);

create table public.classes (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  join_code text not null unique,
  teacher_id uuid not null references public.profiles(id),
  created_at timestamptz not null default now()
);

create table public.class_memberships (
  class_id uuid not null references public.classes(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (class_id, user_id)
);

create table public.sessions (
  id uuid primary key default gen_random_uuid(),
  class_id uuid not null references public.classes(id) on delete cascade,
  created_by uuid not null references public.profiles(id),
  started_at timestamptz not null default now(),
  ended_at timestamptz
);

create table public.heart_rate_readings (
  id bigint generated always as identity primary key,
  session_id uuid not null references public.sessions(id) on delete cascade,
  class_id uuid not null references public.classes(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  bpm smallint not null check (bpm between 25 and 250),
  recorded_at timestamptz not null default now()
);

create or replace function public.is_member_of_class(
  p_class uuid,
  p_user uuid default auth.uid()
)
returns boolean
language sql stable security definer
set search_path = public
as $$
  select exists (
    select 1 from public.class_memberships
    where class_id = p_class and user_id = p_user
  )
$$;

create or replace function public.is_teacher_of_class(
  p_class uuid,
  p_user uuid default auth.uid()
)
returns boolean
language sql stable security definer
set search_path = public
as $$
  select exists (
    select 1 from public.classes
    where id = p_class and teacher_id = p_user
  )
$$;

create or replace function public.can_view_profile(p_target uuid)
returns boolean
language sql stable security definer
set search_path = public
as $$
  select p_target = auth.uid()
    or exists (
      select 1 from public.class_memberships mine
      join public.class_memberships theirs using (class_id)
      where mine.user_id = auth.uid() and theirs.user_id = p_target
    )
    or exists (
      select 1 from public.classes
      where teacher_id = auth.uid()
    )
$$;

create or replace function public.create_class(p_name text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare new_id uuid; code text;
begin
  if (select role from public.profiles where id = auth.uid()) <> 'teacher' then
    raise exception 'Teacher account required';
  end if;
  code := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));
  insert into public.classes(name, join_code, teacher_id)
  values (trim(p_name), code, auth.uid())
  returning id into new_id;
  return new_id;
end
$$;

create or replace function public.join_class(p_join_code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare v_class uuid;
begin
  select id into v_class from public.classes where join_code = upper(trim(p_join_code));
  if v_class is null then raise exception 'Class not found'; end if;
  if (select role from public.profiles where id = auth.uid()) <> 'student' then
    raise exception 'Student account required';
  end if;
  insert into public.class_memberships(class_id, user_id)
  values (v_class, auth.uid()) on conflict do nothing;
  return v_class;
end
$$;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles(id, full_name, role)
  values (new.id, 'New user', 'student');
  return new;
end
$$;

create publication supabase_realtime;
