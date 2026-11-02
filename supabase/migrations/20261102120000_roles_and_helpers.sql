-- App roles and the person-id helper. Table-backed helpers live in the RLS
-- migration so they are created after the schema exists.

create extension if not exists "pgcrypto";

create type public.app_role as enum (
  'student',
  'teacher',
  'parent',
  'school_admin'
);

-- auth.uid() is the person id (profiles.id references auth.users).
create or replace function public.current_person_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select auth.uid();
$$;

revoke all on function public.current_person_id() from public;
grant execute on function public.current_person_id() to authenticated;
