-- Chom staff and the audit log. Both live in the private schema: the apps can never
-- reach them through the Data API. The future admin dashboard reaches them only through
-- specific server functions, each of which writes to the audit log.

create table private.platform_staff (
  profile_id uuid primary key references public.profiles (id) on delete restrict,
  level public.staff_level not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table private.platform_staff is
  'Chom team members with admin dashboard access. Not a school role and grants no access through row-level security.';

create trigger platform_staff_set_updated_at before update on private.platform_staff
  for each row execute function private.set_updated_at();

create table private.audit_log (
  id bigint generated always as identity primary key,
  occurred_at timestamptz not null default now(),
  actor_user_id uuid,
  actor_db_role text not null default current_user,
  school_id uuid,
  table_name text not null,
  record_id uuid,
  action text not null check (action in ('INSERT', 'UPDATE', 'DELETE')),
  old_data jsonb,
  new_data jsonb
);

comment on table private.audit_log is
  'Append-only record of changes to who belongs where. Written by triggers; never updated or deleted by the apps.';

create index audit_log_school_id_occurred_at_idx on private.audit_log (school_id, occurred_at desc);

revoke all on private.platform_staff, private.audit_log from public, anon, authenticated;
grant select on private.platform_staff to service_role;
grant select, insert on private.audit_log to service_role;

-- Records every insert, update and delete on the tables it is attached to.
create function private.audit_row_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  row_data jsonb := case when tg_op = 'DELETE' then to_jsonb(old) else to_jsonb(new) end;
begin
  insert into private.audit_log (actor_user_id, school_id, table_name, record_id, action, old_data, new_data)
  values (
    (select auth.uid()),
    (row_data ->> 'school_id')::uuid,
    tg_table_name,
    (row_data ->> 'id')::uuid,
    tg_op,
    case when tg_op in ('UPDATE', 'DELETE') then to_jsonb(old) end,
    case when tg_op in ('INSERT', 'UPDATE') then to_jsonb(new) end
  );
  return null;
end;
$$;

revoke execute on function private.audit_row_change() from public;

create trigger school_memberships_audit after insert or update or delete on public.school_memberships
  for each row execute function private.audit_row_change();
create trigger guardianships_audit after insert or update or delete on public.guardianships
  for each row execute function private.audit_row_change();
create trigger enrolments_audit after insert or update or delete on public.enrolments
  for each row execute function private.audit_row_change();
create trigger teaching_allocations_audit after insert or update or delete on public.teaching_allocations
  for each row execute function private.audit_row_change();
create trigger classes_audit after insert or update or delete on public.classes
  for each row execute function private.audit_row_change();
create trigger academic_years_audit after insert or update or delete on public.academic_years
  for each row execute function private.audit_row_change();
