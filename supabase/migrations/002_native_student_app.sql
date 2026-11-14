-- Apply this migration to an existing PulseClass Supabase project before deploying v0.3.
alter table public.heart_rate_readings add column if not exists device_name text;
alter table public.heart_rate_readings add column if not exists device_source text not null default 'ble-web';
do $$ begin
  if not exists (select 1 from pg_constraint where conname='heart_rate_readings_device_source_check') then
    alter table public.heart_rate_readings add constraint heart_rate_readings_device_source_check check (device_source in ('ble-web','ble-native','approved-gateway'));
  end if;
end $$;
create index if not exists readings_session_user_time on public.heart_rate_readings(session_id,user_id,recorded_at desc);

-- Public signup metadata must never grant teacher privileges.
create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$
begin
 insert into public.profiles(id,full_name,role,age)
 values(new.id,coalesce(new.raw_user_meta_data->>'full_name','User'),'student',nullif(new.raw_user_meta_data->>'age','')::smallint);
 return new;
end $$;

create or replace function public.validate_heart_rate_reading() returns trigger
language plpgsql security definer set search_path=public as $$
declare last_time timestamptz;
begin
  if new.user_id <> auth.uid() then raise exception 'Reading user must match signed-in user'; end if;
  if not public.is_member_of_class(new.class_id,new.user_id) then raise exception 'Student is not a member of this class'; end if;
  if not exists(select 1 from public.sessions s where s.id=new.session_id and s.class_id=new.class_id and s.ended_at is null) then raise exception 'No active lesson for this reading'; end if;
  select max(r.recorded_at) into last_time from public.heart_rate_readings r where r.session_id=new.session_id and r.user_id=new.user_id;
  if last_time is not null and new.recorded_at < last_time + interval '1.5 seconds' then raise exception 'Heart-rate readings are arriving too quickly'; end if;
  new.device_name := left(coalesce(new.device_name,'Bluetooth HR monitor'),80);
  return new;
end $$;
drop trigger if exists validate_heart_rate_reading on public.heart_rate_readings;
create trigger validate_heart_rate_reading before insert on public.heart_rate_readings for each row execute function public.validate_heart_rate_reading();

-- Correct the existing insert policy to bind the reading's own class/session pair.
drop policy if exists "students insert own session readings" on public.heart_rate_readings;
create policy "students insert own session readings" on public.heart_rate_readings for insert to authenticated with check (
 user_id=auth.uid() and public.is_member_of_class(class_id)
 and exists(select 1 from public.sessions s where s.id=heart_rate_readings.session_id and s.class_id=heart_rate_readings.class_id and s.ended_at is null)
);
