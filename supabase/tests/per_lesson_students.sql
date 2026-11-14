-- Runs only against the disposable PostgreSQL service in CI.
\set ON_ERROR_STOP on

insert into auth.users(id) values
  ('11111111-1111-4111-8111-111111111111'),
  ('22222222-2222-4222-8222-222222222222');
insert into public.profiles(id, full_name, role) values
  ('11111111-1111-4111-8111-111111111111', 'CI Teacher', 'teacher'),
  ('22222222-2222-4222-8222-222222222222', 'Unrelated User', 'student');
insert into public.classes(id, name, join_code, teacher_id)
values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'CI Class', 'ABCDEF123456',
        '11111111-1111-4111-8111-111111111111');
insert into public.sessions(id, class_id, created_by, lesson_title, target_zone, planned_duration_minutes)
values ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
        'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        '11111111-1111-4111-8111-111111111111',
        'CI Lesson', 3, 30);
insert into public.lesson_participants(
  id, session_id, class_id, display_name, token_hash
) values (
  'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  'Test Student',
  repeat('a', 64)
);

-- Join throttling: 99 attempts pass, then the 100th is blocked.
do $$
declare i integer; allowed boolean;
begin
  for i in 1..99 loop
    select public.consume_join_attempt(repeat('b', 64)) into allowed;
    if not allowed then raise exception 'Join attempt % was unexpectedly blocked', i; end if;
  end loop;
  select public.consume_join_attempt(repeat('b', 64)) into allowed;
  if allowed then raise exception '100th join attempt should be blocked'; end if;
end $$;

-- A valid reading is inserted with the server-bound participant/session/class.
select public.record_lesson_reading(
  'cccccccc-cccc-4ccc-8ccc-cccccccccccc', 145::smallint, 'CI heart-rate strap'
);
do $$
begin
  if (select count(id) from public.participant_readings) <> 1 then
    raise exception 'Expected exactly one participant reading';
  end if;
  if not exists (
    select 1 from public.participant_readings
    where participant_id = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc'
      and session_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'
      and class_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
      and bpm = 145
  ) then
    raise exception 'Reading was not bound to the participant lesson';
  end if;
end $$;

-- Concurrent calls are serialized and the minimum interval is enforced.
do $$
begin
  begin
    perform public.record_lesson_reading(
      'cccccccc-cccc-4ccc-8ccc-cccccccccccc', 146::smallint, 'CI heart-rate strap'
    );
    raise exception 'Expected sampling rate limit to reject an immediate second reading';
  exception when others then
    if sqlerrm = 'Expected sampling rate limit to reject an immediate second reading' then
      raise;
    end if;
    if position('rate limit' in lower(sqlerrm)) = 0 then raise; end if;
  end;
end $$;

-- Teachers can read their lesson roster/readings; unrelated authenticated users cannot.
set role authenticated;
select set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', false);
do $$
begin
  if (select count(id) from public.lesson_participants) <> 1 then
    raise exception 'Teacher should see the lesson participant';
  end if;
  if (select count(*) from public.participant_readings) <> 1 then
    raise exception 'Teacher should see the participant reading';
  end if;
end $$;
select set_config('request.jwt.claim.sub', '22222222-2222-4222-8222-222222222222', false);
do $$
begin
  if (select count(id) from public.lesson_participants) <> 0 then
    raise exception 'Unrelated user must not see lesson participants';
  end if;
  if (select count(id) from public.participant_readings) <> 0 then
    raise exception 'Unrelated user must not see participant readings';
  end if;
end $$;
reset role;

-- Ending the lesson revokes every token bound to it.
update public.sessions
set ended_at = now()
where id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
do $$
begin
  if not exists (
    select 1 from public.lesson_participants
    where id = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc'
      and revoked_at is not null
  ) then
    raise exception 'Lesson end did not revoke participant token';
  end if;
end $$;

-- The database rejects cross-session/class participant bindings.
do $$
begin
  begin
    insert into public.participant_readings(
      participant_id, session_id, class_id, bpm
    ) values (
      'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
      'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
      150
    );
    raise exception 'Expected composite participant binding foreign key to reject mismatch';
  exception when foreign_key_violation then
    null;
  end;
end $$;

select 'PulseClass per-lesson database proposal tests passed' as result;
