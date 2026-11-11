-- The name step on a first sign-in: people type whatever name they want, and that
-- becomes their name.
--
-- The page shows which account is signed in ("Signed in as …", with "Not you? Sign
-- out"), so a tab left open on someone else's account is obvious. The name the school
-- first had for the person is kept in school_full_name the first time it's replaced,
-- so it is never lost.

alter table public.profiles add column school_full_name text;

comment on column public.profiles.school_full_name is
  'The name the school had for this person before they chose their own on first sign-in. Null if they never changed it.';

drop function public.confirm_my_name(text);
drop function private.name_key(text);

-- Sets the signed-in person's name to what they typed (tidied) and marks it confirmed.
-- Returns true; refuses a blank name or one over 120 characters.
create function public.confirm_my_name(p_full_name text)
returns boolean
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
  update public.profiles p
     set school_full_name = case
           when p.full_name is distinct from v_name then coalesce(p.school_full_name, p.full_name)
           else p.school_full_name
         end,
         full_name = v_name,
         name_confirmed_at = now()
   where p.id = v_profile_id;
  return true;
end;
$$;

revoke execute on function public.confirm_my_name(text) from public, anon;
grant execute on function public.confirm_my_name(text) to authenticated;
