-- School groups, school email domains, and linking a login to the roster.
--
-- How sign-in finds the right person:
--   * The roster decides who someone is: each membership can carry the email the
--     school knows them by. The email's domain never decides the school.
--   * A school email domain decides which sign-in to trust. Every school belongs to a
--     group (a single school is a group of one; a franchise such as Curro is one group
--     with many campuses). A group registers its domains and how its people sign in,
--     e.g. curro.co.za -> Microsoft, Curro's tenant.
--   * On first sign-in the app calls public.link_my_account(). It links the login to
--     the one roster profile with that email, but only if the login proves the email:
--       - registered school domain: the school's own Microsoft tenant (or Google
--         Workspace), never anything else;
--       - any other email (parents, testing): a one-time email link or Google.

-- ---------------------------------------------------------------------------------
-- 1. School groups
-- ---------------------------------------------------------------------------------

create table public.school_groups (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) > 0),
  slug text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.school_groups is
  'A school, or a franchise of schools, that shares email domains and sign-in. A single school is a group of one.';

create trigger school_groups_set_updated_at before update on public.school_groups
  for each row execute function private.set_updated_at();

alter table public.schools add column school_group_id uuid references public.school_groups (id) on delete restrict;

-- Any school created before groups existed becomes a group of one.
insert into public.school_groups (name, slug)
select s.name, s.slug from public.schools s;

update public.schools s
set school_group_id = g.id
from public.school_groups g
where g.slug = s.slug and s.school_group_id is null;

alter table public.schools alter column school_group_id set not null;

create index schools_school_group_id_idx on public.schools (school_group_id);

-- ---------------------------------------------------------------------------------
-- 2. School email domains and how they sign in
-- ---------------------------------------------------------------------------------

create type public.sign_in_provider as enum ('microsoft', 'google');

create table public.school_group_domains (
  id uuid primary key default gen_random_uuid(),
  school_group_id uuid not null references public.school_groups (id) on delete cascade,
  domain text not null unique
    check (domain ~ '^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$'),
  provider public.sign_in_provider not null,
  -- The school's Microsoft Entra tenant. Only logins from this tenant count.
  microsoft_tenant_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((provider = 'microsoft') = (microsoft_tenant_id is not null))
);

comment on table public.school_group_domains is
  'A school group''s email domains and the only sign-in trusted for them. One domain belongs to one group.';

create index school_group_domains_school_group_id_idx on public.school_group_domains (school_group_id);

create trigger school_group_domains_set_updated_at before update on public.school_group_domains
  for each row execute function private.set_updated_at();

-- ---------------------------------------------------------------------------------
-- 3. The email the school knows each person by
-- ---------------------------------------------------------------------------------

alter table public.school_memberships
  add column email text
    check (email is null or (email = lower(trim(email)) and email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'));

comment on column public.school_memberships.email is
  'The email the school knows this person by (lowercase). Used once, to link their login to this roster entry.';

create index school_memberships_email_idx on public.school_memberships (email) where email is not null;

-- ---------------------------------------------------------------------------------
-- 4. Access
-- ---------------------------------------------------------------------------------

select private.expose_table('public.school_groups', 'select');

create policy "Members can read their school's group"
  on public.school_groups for select to authenticated
  using (
    exists (
      select 1 from public.schools s
      where s.school_group_id = school_groups.id and private.is_member(s.id)
    )
  );

-- Domains are used by link_my_account() on the server. In the apps, only a school
-- group's own admins can see them (for the admin dashboard); they are changed by Chom.
select private.expose_table('public.school_group_domains', 'select');

create policy "School admins can read their group's domains"
  on public.school_group_domains for select to authenticated
  using (
    exists (
      select 1 from public.schools s
      where s.school_group_id = school_group_domains.school_group_id
        and private.is_school_admin(s.id)
    )
  );

-- School admins may correct the email on a roster entry in their school.
grant update (email) on public.school_memberships to authenticated;

-- ---------------------------------------------------------------------------------
-- 5. Linking a login to the roster
-- ---------------------------------------------------------------------------------

-- The Microsoft tenant a Microsoft login came from, or null. Supabase stores the
-- token's claims on the identity: the tenant is the `tid` claim and is also part of
-- the issuer URL.
create function private.microsoft_tenant_id(p_identity_data jsonb)
returns uuid
language sql
immutable
set search_path = ''
as $$
  select case when t ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then t::uuid end
  from (
    select lower(coalesce(
      p_identity_data -> 'custom_claims' ->> 'tid',
      p_identity_data ->> 'tid',
      substring(p_identity_data ->> 'iss' from 'login\.microsoftonline\.com/([0-9A-Fa-f-]{36})/')
    )) as t
  ) s
$$;

-- Only link_my_account() uses it (as its owner); nobody else can call it.
revoke execute on function private.microsoft_tenant_id(jsonb) from public;

-- Links the signed-in login to its roster profile. Safe to call on every sign-in.
-- Returns one of:
--   linked                the login is now linked to its roster profile
--   already_linked        it already was
--   not_on_roster         no active roster entry has this email
--   wrong_sign_in_method  the email's school requires a different sign-in
--   ambiguous             the email belongs to more than one profile (a data error
--                         the school must fix; nothing is linked)
--   profile_taken         the profile is already linked to a different login
create function public.link_my_account()
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
      select 1 from auth.identities i
      where i.user_id = v_user_id
        and (
          (v_rule.provider = 'microsoft' and i.provider = 'azure'
            and private.microsoft_tenant_id(i.identity_data) = v_rule.microsoft_tenant_id)
          or (v_rule.provider = 'google' and i.provider = 'google'
            and lower(i.identity_data ->> 'email') = v_email)
        )
    ) then
      return 'wrong_sign_in_method';
    end if;
  else
    -- Not a school domain: only a one-time email link or Google prove the address.
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
