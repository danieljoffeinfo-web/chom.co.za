-- Foundation: private schema, shared types, and helpers used by every later migration.
--
-- Security model (see docs/decisions/0001-database-platform.md):
--   * Tables in `public` are what the apps can reach through the Data API, and only
--     after `private.expose_table` has switched on row-level security and granted access.
--   * `private` is never exposed through the Data API. Helper functions and internal
--     tables (staff, audit log) live there.
--   * `anon` (signed-out visitors) gets nothing. Every table requires a signed-in user.

create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated, service_role;

-- New functions are not executable by app users unless granted explicitly.
alter default privileges in schema private revoke execute on functions from public;
alter default privileges in schema public revoke execute on functions from public;
alter default privileges in schema public revoke execute on functions from anon, authenticated;

-- ---------------------------------------------------------------------------------
-- Shared types
-- ---------------------------------------------------------------------------------

create type public.membership_role as enum ('student', 'teacher', 'parent', 'school_admin');
create type public.membership_status as enum ('active', 'inactive');

-- A register class is a learner's home class (e.g. 10B). A subject group is a teaching
-- set for one subject (e.g. "10 Physical Sciences Set 2"). Names are free text either way.
create type public.class_kind as enum ('register', 'subject_group');

create type public.staff_level as enum ('support', 'operations', 'owner');

-- ---------------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------------

-- Keeps updated_at current on every row change.
create function private.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- Opens a table to signed-in app users, in one line per table:
--   select private.expose_table('public.classes', 'select, insert, update, delete');
-- It always switches on row-level security first, removes every default grant, and
-- never grants anything to signed-out visitors. What each user can actually see or
-- change is then decided by the table's row-level security policies.
create function private.expose_table(target regclass, privileges text default 'select')
returns void
language plpgsql
set search_path = ''
as $$
begin
  if privileges !~ '^\s*$'
     and privileges !~* '^\s*(select|insert|update|delete)(\s*,\s*(select|insert|update|delete))*\s*$' then
    raise exception 'expose_table: unsupported privileges "%"', privileges;
  end if;

  execute format('alter table %s enable row level security', target);
  execute format('revoke all on table %s from public, anon, authenticated', target);
  if privileges !~ '^\s*$' then
    execute format('grant %s on table %s to authenticated', privileges, target);
  end if;
  execute format('grant all on table %s to service_role', target);
end;
$$;

revoke execute on function private.set_updated_at() from public;
revoke execute on function private.expose_table(regclass, text) from public;
