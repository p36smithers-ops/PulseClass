-- PulseClass: six-digit numeric class join codes.
-- Apply only after reviewing the deployment plan. Existing class codes are rotated
-- to six digits so all classes use one consistent format.
begin;

do $$
declare r record; new_code text;
begin
  for r in select id from public.classes loop
    loop
      new_code := lpad(floor(random() * 1000000)::bigint::text, 6, '0');
      exit when not exists (select 1 from public.classes where join_code = new_code and id <> r.id);
    end loop;
    update public.classes set join_code = new_code where id = r.id;
  end loop;
end $$;

create or replace function public.create_class(p_name text)
returns uuid
language plpgsql
security definer
set search_path = public
as $function$
declare
  new_id uuid;
  code text;
begin
  if (select role from public.profiles where id = auth.uid()) is distinct from 'teacher' then
    raise exception 'Teacher account required';
  end if;
  if p_name is null or char_length(btrim(p_name)) not between 1 and 80 then
    raise exception 'Class name must be between 1 and 80 characters';
  end if;
  loop
    code := lpad(floor(random() * 1000000)::bigint::text, 6, '0');
    exit when not exists (select 1 from public.classes where join_code = code);
  end loop;
  insert into public.classes(name, join_code, teacher_id)
    values (btrim(p_name), code, auth.uid())
    returning id into new_id;
  return new_id;
end
$function$;

commit;
