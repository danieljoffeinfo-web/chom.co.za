-- The last step of a first sign-in: the person types their full name.
--
-- Signing in for the first time is: email, a password, the code we email them, then
-- their full name. The name is filled in from the school's list, and whatever they
-- type replaces it. name_confirmed_at records that they've done it, so it's asked
-- only once.

alter table public.profiles add column name_confirmed_at timestamptz;

comment on column public.profiles.name_confirmed_at is
  'When the person confirmed their full name on their first sign-in. Null until then.';

-- Sets the signed-in person's full name and marks it confirmed.
create function public.confirm_my_name(p_full_name text)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_profile_id uuid := private.current_profile_id();
  -- Squeeze every run of whitespace (tabs, newlines) to one space, then trim.
  v_name text := trim(regexp_replace(coalesce(p_full_name, ''), '\s+', ' ', 'g'));
begin
  if v_profile_id is null then
    raise exception 'confirm_my_name: not linked to a profile' using errcode = '42501';
  end if;
  if length(v_name) < 2 or length(v_name) > 120 then
    raise exception 'confirm_my_name: a name is 2 to 120 characters' using errcode = '22023';
  end if;
  update public.profiles
     set full_name = v_name, name_confirmed_at = now()
   where id = v_profile_id;
end;
$$;

revoke execute on function public.confirm_my_name(text) from public, anon;
grant execute on function public.confirm_my_name(text) to authenticated;
