-- A school can sign in with an emailed code.
--
-- A school's email domain decides which sign-in Chom trusts for it. Until now that was
-- the school's Microsoft tenant or Google Workspace. Some schools want the simplest
-- thing: type your school email, get a 6-digit code, and you're in. The code proves
-- the mailbox is theirs, which is all the roster needs to link the right person.
--
-- With provider = 'email_code' on a domain, link_my_account() accepts a confirmed
-- email login (Supabase's 'email' identity) for that domain. Microsoft and Google
-- logins are not accepted for it: one domain, one way in.
--
-- Also: "Afrikaans SL" and "Afrikaans Second Language" as other names for Afrikaans
-- First Additional Language, the level schools usually mean by them.

alter type public.sign_in_provider add value if not exists 'email_code';

create or replace function public.link_my_account()
returns text
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_email text;
  v_rule public.school_group_domains;
  v_profile_ids uuid[];
begin
  if v_user_id is null then
    raise exception 'link_my_account: not signed in' using errcode = '42501';
  end if;

  if exists (select 1 from public.profiles p where p.user_id = v_user_id) then
    return 'already_linked';
  end if;

  select lower(trim(u.email)) into v_email from auth.users u where u.id = v_user_id;
  if v_email is null then
    return 'not_on_roster';
  end if;

  select d.* into v_rule
  from public.school_group_domains d
  where d.domain = split_part(v_email, '@', 2);

  -- The login must prove the email, in the way its school allows.
  if v_rule.id is not null then
    if not exists (
      select 1
      from auth.identities i
      join auth.users u on u.id = i.user_id
      where i.user_id = v_user_id
        and (
          (v_rule.provider = 'microsoft' and i.provider = 'azure'
            and private.microsoft_tenant_id(i.identity_data) = v_rule.microsoft_tenant_id)
          or (v_rule.provider = 'google' and i.provider = 'google'
            and lower(i.identity_data ->> 'email') = v_email)
          or (v_rule.provider::text = 'email_code' and i.provider = 'email'
            and lower(i.identity_data ->> 'email') = v_email
            and u.email_confirmed_at is not null)
        )
    ) then
      return 'wrong_sign_in_method';
    end if;
  else
    -- Not a school domain: only a one-time email code or Google prove the address.
    -- Microsoft logins from other tenants are never trusted for this.
    if not exists (
      select 1
      from auth.identities i
      join auth.users u on u.id = i.user_id
      where i.user_id = v_user_id
        and i.provider in ('email', 'google')
        and lower(i.identity_data ->> 'email') = v_email
        and u.email_confirmed_at is not null
    ) then
      return 'wrong_sign_in_method';
    end if;
  end if;

  select array_agg(distinct m.profile_id) into v_profile_ids
  from public.school_memberships m
  where m.email = v_email and m.status = 'active';

  if v_profile_ids is null then
    return 'not_on_roster';
  elsif cardinality(v_profile_ids) > 1 then
    return 'ambiguous';
  end if;

  update public.profiles set user_id = v_user_id
  where id = v_profile_ids[1] and user_id is null;

  if not found then
    return 'profile_taken';
  end if;

  insert into private.audit_log (actor_user_id, actor_db_role, school_id, table_name, record_id, action, old_data, new_data)
  values (
    v_user_id,
    coalesce(nullif(current_setting('role', true), 'none'), session_user),
    null,
    'profiles',
    v_profile_ids[1],
    'UPDATE',
    jsonb_build_object('user_id', null),
    jsonb_build_object('user_id', v_user_id, 'linked_by_email', v_email)
  );

  return 'linked';
end;
$$;

comment on function public.link_my_account() is
  'Links the signed-in login to its roster profile by verified email. Call after every sign-in.';

revoke execute on function public.link_my_account() from public, anon;
grant execute on function public.link_my_account() to authenticated;

insert into public.curriculum_subject_aliases (curriculum_id, curriculum_subject_id, alias, min_grade, max_grade)
select s.curriculum_id, s.id, a.alias, s.min_grade, s.max_grade
from public.curriculum_subjects s
join public.curricula c on c.id = s.curriculum_id
cross join (values ('Afrikaans SL'), ('Afrikaans Second Language')) as a (alias)
where c.code = 'IEB' and s.name = 'Afrikaans First Additional Language';
