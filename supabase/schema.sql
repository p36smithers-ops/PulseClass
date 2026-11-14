-- PulseClass production starter schema for Supabase (Postgres)
-- Run in Supabase SQL Editor. Review with your school's data-protection lead before real student use.
create extension if not exists pgcrypto;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default 'User',
  role text not null check (role in ('teacher','student')),
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
  class_id uuid references public.classes(id) on delete cascade,
  user_id uuid references public.profiles(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key(class_id,user_id)
);
create table public.sessions (
  id uuid primary key default gen_random_uuid(),
  class_id uuid not null references public.classes(id) on delete cascade,
  created_by uuid not null references public.profiles(id),
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  lesson_title text not null default 'Sports science lesson',
  target_zone smallint not null default 3 check (target_zone between 1 and 5),
  planned_duration_minutes smallint not null default 30 check (planned_duration_minutes between 1 and 240)
);
create table public.heart_rate_readings (
  id bigint generated always as identity primary key,
  session_id uuid not null references public.sessions(id) on delete cascade,
  class_id uuid not null references public.classes(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  bpm smallint not null check (bpm between 25 and 250),
  device_name text,
  device_source text not null default 'ble-web' check (device_source in ('ble-web','ble-native','approved-gateway')),
  recorded_at timestamptz not null default now()
);
create index readings_session_time on public.heart_rate_readings(session_id,recorded_at);
create index readings_class_time on public.heart_rate_readings(class_id,recorded_at desc);
create index readings_session_user_time on public.heart_rate_readings(session_id,user_id,recorded_at desc);

-- Create a profile from signup metadata. Production deployments should restrict who may self-register as teacher.
create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$
begin
 insert into public.profiles(id,full_name,role,age)
 values(new.id,coalesce(new.raw_user_meta_data->>'full_name','User'),
 'student', -- staff must be promoted by an administrator; never trust public signup metadata
 nullif(new.raw_user_meta_data->>'age','')::smallint);
 return new;
end $$;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();

create or replace function public.create_class(p_name text) returns uuid language plpgsql security definer set search_path=public as $$
declare new_id uuid; code text;
begin
 if (select role from public.profiles where id=auth.uid()) <> 'teacher' then raise exception 'Teacher account required'; end if;
 code := upper(substr(encode(gen_random_bytes(8),'hex'),1,8));
 insert into public.classes(name,join_code,teacher_id) values(p_name,code,auth.uid()) returning id into new_id;
 return new_id;
end $$;

create or replace function public.join_class(p_join_code text) returns uuid language plpgsql security definer set search_path=public as $$
declare cid uuid;
begin
 select id into cid from public.classes where join_code=upper(trim(p_join_code));
 if cid is null then raise exception 'Invalid class code'; end if;
 if (select role from public.profiles where id=auth.uid()) <> 'student' then raise exception 'Student account required'; end if;
 insert into public.class_memberships(class_id,user_id) values(cid,auth.uid()) on conflict do nothing;
 return cid;
end $$;

alter table public.profiles enable row level security;
alter table public.classes enable row level security;
alter table public.class_memberships enable row level security;
alter table public.sessions enable row level security;

alter table public.heart_rate_readings enable row level security;

-- SECURITY DEFINER helpers avoid recursive RLS policy evaluation.
create or replace function public.is_teacher_of_class(p_class uuid,p_user uuid default auth.uid())
returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from public.classes c where c.id=p_class and c.teacher_id=p_user)
$$;
create or replace function public.is_member_of_class(p_class uuid,p_user uuid default auth.uid())
returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from public.class_memberships m where m.class_id=p_class and m.user_id=p_user)
$$;
create or replace function public.can_view_profile(p_target uuid)
returns boolean language sql stable security definer set search_path=public as $$
 select p_target=auth.uid()
 or exists(select 1 from public.class_memberships mine join public.class_memberships theirs on mine.class_id=theirs.class_id where mine.user_id=auth.uid() and theirs.user_id=p_target)
 or exists(select 1 from public.classes c join public.class_memberships m on m.class_id=c.id where c.teacher_id=auth.uid() and m.user_id=p_target)
$$;

-- Server-side validation protects against modified clients bypassing the UI's sampling interval.
create or replace function public.validate_heart_rate_reading() returns trigger
language plpgsql security definer set search_path=public as $$
declare last_time timestamptz;
begin
  if new.user_id <> auth.uid() then raise exception 'Reading user must match signed-in user'; end if;
  if not public.is_member_of_class(new.class_id,new.user_id) then raise exception 'Student is not a member of this class'; end if;
  if not exists(select 1 from public.sessions s where s.id=new.session_id and s.class_id=new.class_id and s.ended_at is null) then
    raise exception 'No active lesson for this reading';
  end if;
  select max(r.recorded_at) into last_time from public.heart_rate_readings r where r.session_id=new.session_id and r.user_id=new.user_id;
  if last_time is not null and new.recorded_at < last_time + interval '1.5 seconds' then
    raise exception 'Heart-rate readings are arriving too quickly';
  end if;
  new.device_name := left(coalesce(new.device_name,'Bluetooth HR monitor'),80);
  return new;
end $$;
drop trigger if exists validate_heart_rate_reading on public.heart_rate_readings;
create trigger validate_heart_rate_reading before insert on public.heart_rate_readings
for each row execute function public.validate_heart_rate_reading();


create policy "profiles self and permitted class users" on public.profiles for select to authenticated using(public.can_view_profile(id));
create policy "users update own profile" on public.profiles for update to authenticated using(id=auth.uid()) with check(id=auth.uid());
create policy "class members and teacher read class" on public.classes for select to authenticated using(teacher_id=auth.uid() or public.is_member_of_class(id));
create policy "teacher creates own classes" on public.classes for insert to authenticated with check(teacher_id=auth.uid());
create policy "teacher or student reads membership" on public.class_memberships for select to authenticated using(user_id=auth.uid() or public.is_teacher_of_class(class_id));
create policy "class participants read sessions" on public.sessions for select to authenticated using(public.is_teacher_of_class(class_id) or public.is_member_of_class(class_id));
create policy "teacher starts session" on public.sessions for insert to authenticated with check(created_by=auth.uid() and public.is_teacher_of_class(class_id));
create policy "teacher ends session" on public.sessions for update to authenticated using(public.is_teacher_of_class(class_id)) with check(public.is_teacher_of_class(class_id));
create policy "students insert own session readings" on public.heart_rate_readings for insert to authenticated with check(
 user_id=auth.uid() and public.is_member_of_class(class_id)
 and exists(select 1 from public.sessions s where s.id=heart_rate_readings.session_id and s.class_id=heart_rate_readings.class_id and s.ended_at is null)
);
create policy "teachers and owner read class readings" on public.heart_rate_readings for select to authenticated using(public.is_teacher_of_class(class_id) or user_id=auth.uid());

grant usage on schema public to authenticated;
grant select,update on public.profiles to authenticated;
grant select,insert on public.classes to authenticated;
grant select on public.class_memberships to authenticated;
grant select,insert,update on public.sessions to authenticated;
grant select,insert on public.heart_rate_readings to authenticated;
grant execute on function public.create_class(text) to authenticated;
grant execute on function public.join_class(text) to authenticated;
grant execute on function public.is_teacher_of_class(uuid,uuid) to authenticated;
grant execute on function public.is_member_of_class(uuid,uuid) to authenticated;
grant execute on function public.can_view_profile(uuid) to authenticated;

-- Enable Realtime on heart_rate_readings in Supabase Dashboard > Database > Publications.
alter publication supabase_realtime add table public.heart_rate_readings;
