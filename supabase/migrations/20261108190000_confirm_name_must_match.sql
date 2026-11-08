-- The name step on a first sign-in checks the name; it never changes it.
--
-- Before, whatever the person typed replaced the name on the school's list. A tab
-- still signed in to someone else's account (or anyone at their keyboard) could
-- rename that account: a student's account was renamed this way. Now the typed name
-- must match the school's name for the account (capitals, spaces, hyphens and
-- apostrophes aside; middle names may be left out). It is recorded as confirmed only
-- if it does, and the school's name is never touched. Changing a name is the
-- school's job.

drop function public.confirm_my_name(text);

-- A name reduced to lowercase letters and single spaces, for comparing.
create function private.name_key(p_name text)
returns text
language sql
immutable
set search_path = ''
as $$
  select trim(regexp_replace(lower(coalesce(p_name, '')), '[^[:alpha:]]+', ' ', 'g'))
$$;

revoke execute on function private.name_key(text) from public;

-- True (and the name is confirmed) if p_full_name matches the signed-in person's
-- name on the school's list; false if it doesn't (nothing changes).
create function public.confirm_my_name(p_full_name text)
returns boolean
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_profile_id uuid := private.current_profile_id();
  v_typed text := private.name_key(p_full_name);
begin
  if v_profile_id is null then
    raise exception 'confirm_my_name: not linked to a profile' using errcode = '42501';
  end if;
  if length(v_typed) < 2 or length(v_typed) > 120 then
    raise exception 'confirm_my_name: a name is 2 to 120 characters' using errcode = '22023';
  end if;
  -- The whole name, or just the first name and surname (middle names left out).
  update public.profiles p
     set name_confirmed_at = now()
   where p.id = v_profile_id
     and v_typed in (
       private.name_key(p.full_name),
       split_part(private.name_key(p.full_name), ' ', 1) || ' '
         || regexp_replace(private.name_key(p.full_name), '^.* ', '')
     );
  return found;
end;
$$;

revoke execute on function public.confirm_my_name(text) from public, anon;
grant execute on function public.confirm_my_name(text) to authenticated;

-- Names confirmed under the old rule may have been typed over: ask again.
update public.profiles set name_confirmed_at = null where name_confirmed_at is not null;
