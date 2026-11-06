-- Parent dashboard, slice 1: guardian links with a status, and POPIA consent.
--
-- See docs/design/parent-dashboard.md, sections 2, 3 and 8. The spec sketches separate
-- `guardians` and `guardian_learner_links` tables; here a guardian is a profile with a
-- parent membership (as before) and the link is public.guardianships, which gains a
-- status. Same rules, no second copy of who is who.
--
-- What changes for parents: they see their child's data only while the link is
-- `active` AND they have consented to the current consent version for that child.
-- Every existing parent access rule goes through private.is_parent_of(), so changing
-- that one function gates all of them at once (classes, enrolments, teachers, study
-- habits, goals, and everything added later that uses it).
--
--   invited            Created from the roster. Nothing visible until consent.
--   active             Consented. Sees what section 2 of the spec allows.
--   blocked            Set by a school admin (court order, custody). Sees nothing for
--                      that child, not even that the link exists.
--   consent_withdrawn  The parent withdrew consent. Sees no child data.
--   learner_revoked    The learner (18+) declined parent access. Sees no child data.
--
-- School news and events (visible to withdrawn and revoked links) come in a later
-- slice; nothing here exposes them yet.

-- ---------------------------------------------------------------------------------
-- 1. Guardian links: status, relationship, primary guardian
-- ---------------------------------------------------------------------------------

create type public.guardianship_status as enum (
  'invited', 'active', 'blocked', 'consent_withdrawn', 'learner_revoked'
);

create type public.guardian_relationship as enum ('mother', 'father', 'guardian', 'other');

alter table public.guardianships
  add column status public.guardianship_status not null default 'invited',
  add column is_primary boolean not null default false,
  add column invited_at timestamptz not null default now(),
  add column activated_at timestamptz,
  add column blocked_reason text,
  add column blocked_at timestamptz;

-- relationship was free text. Keep known values, map anything else to 'other'.
update public.guardianships
set relationship = 'other'
where relationship is null or relationship not in ('mother', 'father', 'guardian', 'other');

alter table public.guardianships
  alter column relationship type public.guardian_relationship
    using relationship::public.guardian_relationship,
  alter column relationship set default 'guardian',
  alter column relationship set not null,
  add constraint guardianships_blocked_has_reason
    check (status <> 'blocked' or (blocked_reason is not null and length(trim(blocked_reason)) > 0));

comment on column public.guardianships.status is
  'invited until the parent consents; active after. blocked (by a school admin), consent_withdrawn and learner_revoked hide the child''s data.';
comment on column public.guardianships.is_primary is
  'The primary guardian receives fee and admin communication where relevant.';
comment on column public.guardianships.blocked_reason is
  'Why a school admin blocked this guardian (for example a court order). Required when blocked.';

-- One primary guardian per child per school.
create unique index guardianships_one_primary_per_child
  on public.guardianships (school_id, student_profile_id) where is_primary;

-- Blocking is recorded with a time; unblocking clears it.
create function private.guardianship_track_block()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.status = 'blocked' and old.status is distinct from 'blocked' then
    new.blocked_at := now();
  elsif new.status <> 'blocked' then
    new.blocked_at := null;
    new.blocked_reason := null;
  end if;
  return new;
end;
$$;

revoke execute on function private.guardianship_track_block() from public;

create trigger guardianships_track_block before insert or update of status on public.guardianships
  for each row execute function private.guardianship_track_block();

-- ---------------------------------------------------------------------------------
-- 2. Consent versions and parent consents
-- ---------------------------------------------------------------------------------

-- The versions of the parent consent text. The wording lives in the app
-- (apps/web/src/lib/parent/consent.ts), keyed by version; this table says which
-- version is current. Publishing a new version makes every parent consent again at
-- their next sign-in. Chom-wide, so no school_id.
create table public.parent_consent_versions (
  version text primary key check (version ~ '^[0-9]{4}-[0-9]{2}-[a-z0-9-]+$'),
  published_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

comment on table public.parent_consent_versions is
  'Versions of the parent POPIA consent. The latest published one is current; the wording is in the web app, keyed by version.';

-- The current version: the latest one already published.
create function private.current_parent_consent_version()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select v.version
  from public.parent_consent_versions v
  where v.published_at <= now()
  order by v.published_at desc, v.version desc
  limit 1
$$;

-- One row per consent given, per child. Never updated except to record withdrawal.
create table public.parent_consents (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null,
  guardianship_id uuid not null,
  parent_profile_id uuid not null references public.profiles (id) on delete restrict,
  student_profile_id uuid not null references public.profiles (id) on delete restrict,
  consent_version text not null references public.parent_consent_versions (version) on delete restrict,
  granted_at timestamptz not null default now(),
  withdrawn_at timestamptz,
  ip inet,
  user_agent text check (user_agent is null or length(user_agent) <= 1000),
  created_at timestamptz not null default now(),
  check (withdrawn_at is null or withdrawn_at >= granted_at),
  foreign key (guardianship_id) references public.guardianships (id) on delete cascade
);

comment on table public.parent_consents is
  'A parent''s POPIA consent (s35) to Chom processing one child''s information, for one consent version. Written only by record_parent_consent().';

-- At most one standing consent per link and version, even if the consent screen is
-- submitted twice at once. Withdrawn rows stay for the audit trail.
create unique index parent_consents_guardianship_idx
  on public.parent_consents (guardianship_id, consent_version) where withdrawn_at is null;
create index parent_consents_school_id_idx on public.parent_consents (school_id);
create index parent_consents_parent_idx on public.parent_consents (parent_profile_id);
create index parent_consents_student_idx on public.parent_consents (student_profile_id);
create index parent_consents_version_idx on public.parent_consents (consent_version);

create trigger parent_consents_audit after insert or update or delete on public.parent_consents
  for each row execute function private.audit_row_change();

-- Moving a link to a different parent or child (a school admin correcting the roster)
-- voids its consent: whoever consented is no longer the person linked, or consented
-- for a different child. The consent is marked withdrawn and the link goes back to
-- invited, so the new pair must consent before anything is visible. Blocked stays
-- blocked. security definer, because admins can't write consents themselves.
create function private.guardianship_reset_consent()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.parent_profile_id is distinct from old.parent_profile_id
     or new.student_profile_id is distinct from old.student_profile_id then
    update public.parent_consents
    set withdrawn_at = now()
    where guardianship_id = old.id and withdrawn_at is null;
    if new.status in ('active', 'consent_withdrawn') then
      new.status := 'invited';
      new.activated_at := null;
    end if;
  end if;
  return new;
end;
$$;

revoke execute on function private.guardianship_reset_consent() from public;

create trigger guardianships_reset_consent
  before update of parent_profile_id, student_profile_id on public.guardianships
  for each row execute function private.guardianship_reset_consent();

-- Which channels a parent agreed to hear from Chom on, chosen on the consent screen.
-- Per person (one parent, many schools), so no school_id. The tiers and quiet hours
-- in section 7 of the spec build on this later.
create table public.parent_notification_channels (
  profile_id uuid primary key references public.profiles (id) on delete cascade,
  whatsapp boolean not null default false,
  email boolean not null default true,
  push boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.parent_notification_channels is
  'The channels a parent opted in to (WhatsApp, email, push). One row per person.';

create trigger parent_notification_channels_set_updated_at
  before update on public.parent_notification_channels
  for each row execute function private.set_updated_at();

-- ---------------------------------------------------------------------------------
-- 3. Parent access now needs an active link and current consent
-- ---------------------------------------------------------------------------------

-- Does the signed-in person (as an active parent) have an active, consented link to
-- this child, and no blocked link to them anywhere? Replaces the version that only
-- checked the link existed.
--
-- A block applies to the child at every school: a court order is about the person,
-- not the campus, so a parent blocked at one school can't see the child's records
-- through a link at another.
create or replace function private.is_parent_of(p_student_profile_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.guardianships g
    join public.school_memberships m
      on m.school_id = g.school_id
     and m.profile_id = g.parent_profile_id
     and m.role = 'parent'
     and m.status = 'active'
    join public.parent_consents pc
      on pc.guardianship_id = g.id
     and pc.consent_version = (select private.current_parent_consent_version())
     and pc.withdrawn_at is null
    where g.student_profile_id = p_student_profile_id
      and g.parent_profile_id = (select private.current_profile_id())
      and g.status = 'active'
  )
  and not exists (
    select 1
    from public.guardianships b
    where b.student_profile_id = p_student_profile_id
      and b.parent_profile_id = (select private.current_profile_id())
      and b.status = 'blocked'
  )
$$;

-- A blocked guardian must not even learn that the link exists, so they no longer see
-- their own blocked link row. Everyone else sees what they saw before.
drop policy "Visible to admins, the parent, the child and their teachers" on public.guardianships;

create policy "Visible to admins, the parent, the child and their teachers"
  on public.guardianships for select to authenticated
  using (
    private.is_school_admin(school_id)
    or (
      parent_profile_id = (select private.current_profile_id())
      and private.has_role(school_id, 'parent')
      and status <> 'blocked'
    )
    or (
      student_profile_id = (select private.current_profile_id())
      and private.has_role(school_id, 'student')
    )
    or private.teaches_student(student_profile_id)
  );

-- Why a link was blocked (for example a court order reference) is for school admins
-- only. Students and teachers can still see that a link exists and its status, so
-- staff know not to release a child to a blocked guardian, but not the reason: every
-- column except blocked_reason is readable. Admin screens will read the reason
-- through a function; until then it is visible with the service role only. A column
-- added to guardianships later must be added to this list to be readable.
revoke select on public.guardianships from authenticated;
grant select (
  id, school_id, parent_profile_id, student_profile_id, parent_role, student_role,
  relationship, ednana_id, created_at, updated_at,
  status, is_primary, invited_at, activated_at, blocked_at
) on public.guardianships to authenticated;

-- ---------------------------------------------------------------------------------
-- 4. Access rules for the new tables
-- ---------------------------------------------------------------------------------

select private.expose_table('public.parent_consent_versions', 'select');
select private.expose_table('public.parent_consents', 'select');
select private.expose_table('public.parent_notification_channels', 'select, insert, update');

create policy "Signed-in people can read the consent versions"
  on public.parent_consent_versions for select to authenticated
  using (true);

-- Parents see their own consents (not for blocked links); school admins see the
-- consents for their school. Nobody writes directly: record_parent_consent() and
-- withdraw_parent_consent() do.
create policy "Visible to the parent who gave it and school admins"
  on public.parent_consents for select to authenticated
  using (
    private.is_school_admin(school_id)
    or (
      parent_profile_id = (select private.current_profile_id())
      and exists (
        select 1 from public.guardianships g
        where g.id = guardianship_id and g.status <> 'blocked'
      )
    )
  );

create policy "Parents see their own channels"
  on public.parent_notification_channels for select to authenticated
  using (profile_id = (select private.current_profile_id()));

create policy "Parents set their own channels"
  on public.parent_notification_channels for insert to authenticated
  with check (profile_id = (select private.current_profile_id()));

create policy "Parents change their own channels"
  on public.parent_notification_channels for update to authenticated
  using (profile_id = (select private.current_profile_id()))
  with check (profile_id = (select private.current_profile_id()));

-- ---------------------------------------------------------------------------------
-- 5. What the parent app calls
-- ---------------------------------------------------------------------------------

-- The signed-in parent's links, for the consent screen and the child switcher: each
-- child's name, school, grade this year, relationship, status and whether consent for
-- the current version is on record. Blocked links are left out entirely.
--
-- security definer, because before consent the parent can't read the child's profile
-- yet; it returns only the caller's own links and only the names the consent screen
-- has to show (the parent knows their own child's name and school).
create function public.my_guardian_links()
returns table (
  guardianship_id uuid,
  school_id uuid,
  school_name text,
  student_profile_id uuid,
  student_name text,
  grade smallint,
  relationship public.guardian_relationship,
  is_primary boolean,
  status public.guardianship_status,
  consented boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    g.id,
    g.school_id,
    s.name,
    g.student_profile_id,
    coalesce(child.preferred_name, child.full_name),
    (
      select min(c.grade)
      from public.enrolments e
      join public.classes c on c.id = e.class_id
      join public.academic_years y on y.id = c.academic_year_id and y.is_current
      where e.student_profile_id = g.student_profile_id
        and e.school_id = g.school_id
    ),
    g.relationship,
    g.is_primary,
    g.status,
    exists (
      select 1 from public.parent_consents pc
      where pc.guardianship_id = g.id
        and pc.consent_version = (select private.current_parent_consent_version())
        and pc.withdrawn_at is null
    )
  from public.guardianships g
  join public.school_memberships m
    on m.school_id = g.school_id
   and m.profile_id = g.parent_profile_id
   and m.role = 'parent'
   and m.status = 'active'
  join public.schools s on s.id = g.school_id
  join public.profiles child on child.id = g.student_profile_id
  where g.parent_profile_id = (select private.current_profile_id())
    and g.status <> 'blocked'
  order by coalesce(child.preferred_name, child.full_name), s.name
$$;

comment on function public.my_guardian_links() is
  'The signed-in parent''s links to their children (never blocked ones), with consent status. Names only; child data still needs consent.';

-- Records the signed-in parent's consent to the current version, for every child
-- linked to them that can consent (invited, active or previously withdrawn), and
-- switches those links to active. Also saves the channels they opted in to.
--
-- p_version must be the current version: the screen the parent read must be the one
-- on record. IP and user agent come from the web server, not the browser.
--
-- Returns how many children the consent now covers.
create function public.record_parent_consent(
  p_version text,
  p_whatsapp boolean,
  p_email boolean,
  p_push boolean,
  p_ip inet default null,
  p_user_agent text default null
)
returns integer
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  me uuid := (select private.current_profile_id());
  current_version text := (select private.current_parent_consent_version());
  covered integer;
begin
  if me is null then
    raise exception 'Not signed in' using errcode = '42501';
  end if;
  if p_version is distinct from current_version then
    raise exception 'That consent version is not the current one' using errcode = '22023';
  end if;

  insert into public.parent_consents
    (school_id, guardianship_id, parent_profile_id, student_profile_id, consent_version, ip, user_agent)
  select g.school_id, g.id, g.parent_profile_id, g.student_profile_id, current_version,
         p_ip, left(p_user_agent, 1000)
  from public.guardianships g
  join public.school_memberships m
    on m.school_id = g.school_id
   and m.profile_id = g.parent_profile_id
   and m.role = 'parent'
   and m.status = 'active'
  where g.parent_profile_id = me
    and g.status in ('invited', 'active', 'consent_withdrawn')
    and not exists (
      select 1 from public.parent_consents pc
      where pc.guardianship_id = g.id
        and pc.consent_version = current_version
        and pc.withdrawn_at is null
    )
  on conflict (guardianship_id, consent_version) where withdrawn_at is null do nothing;

  update public.guardianships g
  set status = 'active', activated_at = coalesce(g.activated_at, now())
  from public.school_memberships m
  where m.school_id = g.school_id
    and m.profile_id = g.parent_profile_id
    and m.role = 'parent'
    and m.status = 'active'
    and g.parent_profile_id = me
    and g.status in ('invited', 'consent_withdrawn');

  insert into public.parent_notification_channels (profile_id, whatsapp, email, push)
  values (me, coalesce(p_whatsapp, false), coalesce(p_email, false), coalesce(p_push, false))
  on conflict (profile_id) do update
    set whatsapp = excluded.whatsapp, email = excluded.email, push = excluded.push;

  select count(*) into covered
  from public.guardianships g
  join public.parent_consents pc
    on pc.guardianship_id = g.id
   and pc.consent_version = current_version
   and pc.withdrawn_at is null
  where g.parent_profile_id = me and g.status = 'active';

  return covered;
end;
$$;

comment on function public.record_parent_consent(text, boolean, boolean, boolean, inet, text) is
  'The signed-in parent consents to the current version for each child they can consent for. Activates those links.';

-- The signed-in parent withdraws consent for one child. Their link becomes
-- consent_withdrawn and the child's data is hidden from them at once.
create function public.withdraw_parent_consent(p_guardianship_id uuid)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  me uuid := (select private.current_profile_id());
begin
  if me is null then
    raise exception 'Not signed in' using errcode = '42501';
  end if;

  update public.guardianships g
  set status = 'consent_withdrawn'
  where g.id = p_guardianship_id
    and g.parent_profile_id = me
    and g.status = 'active';
  if not found then
    raise exception 'No active link to withdraw' using errcode = '22023';
  end if;

  update public.parent_consents pc
  set withdrawn_at = now()
  where pc.guardianship_id = p_guardianship_id
    and pc.withdrawn_at is null;
end;
$$;

comment on function public.withdraw_parent_consent(uuid) is
  'The signed-in parent withdraws consent for one child; the link becomes consent_withdrawn.';

revoke execute on function
  private.current_parent_consent_version(),
  private.guardianship_track_block()
from public;
grant execute on function private.current_parent_consent_version() to authenticated;

revoke execute on function
  public.my_guardian_links(),
  public.record_parent_consent(text, boolean, boolean, boolean, inet, text),
  public.withdraw_parent_consent(uuid)
from public, anon;
grant execute on function
  public.my_guardian_links(),
  public.record_parent_consent(text, boolean, boolean, boolean, inet, text),
  public.withdraw_parent_consent(uuid)
to authenticated;

-- The first consent version. Its wording is DRAFT_2026_11 in the web app, pending
-- POPIA counsel review before the first school goes live.
insert into public.parent_consent_versions (version, published_at)
values ('2026-11-draft-1', '2026-11-03 00:00:00+00');
