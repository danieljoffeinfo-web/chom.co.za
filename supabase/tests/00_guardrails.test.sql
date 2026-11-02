-- Guardrails: structural rules every table and function must follow, so a forgotten
-- table or a careless function fails CI instead of being exposed.

begin;
create extension if not exists pgtap with schema extensions;

select plan(8);

select is_empty(
  $$ select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
     where n.nspname = 'public' and c.relkind in ('r', 'p') and not c.relrowsecurity $$,
  'Every table in public has row-level security switched on'
);

select is_empty(
  $$ select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
     where n.nspname = 'public' and c.relkind in ('r', 'p')
       and not exists (select 1 from pg_policy p where p.polrelid = c.oid) $$,
  'Every table in public has at least one access rule'
);

select is_empty(
  $$ select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
     where n.nspname = 'public' and c.relkind in ('r', 'p', 'v', 'm')
       and has_table_privilege('anon', c.oid, 'SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER') $$,
  'Signed-out visitors (anon) have no access to any table or view'
);

select is_empty(
  $$ select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
     where n.nspname = 'public' and c.relkind in ('r', 'p')
       and has_table_privilege('authenticated', c.oid, 'TRUNCATE, REFERENCES, TRIGGER') $$,
  'Signed-in users cannot truncate, reference or add triggers to any table'
);

select is_empty(
  $$ select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
     where n.nspname = 'private' and c.relkind in ('r', 'p', 'v', 'm')
       and (has_table_privilege('authenticated', c.oid, 'SELECT, INSERT, UPDATE, DELETE')
            or has_table_privilege('anon', c.oid, 'SELECT, INSERT, UPDATE, DELETE')) $$,
  'App users cannot touch private tables (staff, audit log)'
);

select is_empty(
  $$ select p.proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'private' and p.prosecdef
       and not exists (select 1 from unnest(coalesce(p.proconfig, '{}')) cfg where cfg like 'search_path=%') $$,
  'Every privileged (security definer) function pins its search_path'
);

select is_empty(
  $$ select p.proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname in ('public', 'private')
       and has_function_privilege('anon', p.oid, 'EXECUTE')
       and not exists (select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e') $$,
  'Signed-out visitors cannot run any of our functions'
);

select is_empty(
  $$ select p.proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'private'
       and p.proname in ('expose_table', 'audit_row_change', 'set_updated_at')
       and has_function_privilege('authenticated', p.oid, 'EXECUTE') $$,
  'Signed-in users cannot run the internal admin helpers'
);

select * from finish();
rollback;
