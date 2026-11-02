-- Who can change what. Only school admins manage records, and only in their own
-- school. Everyone can change their own preferred name and nothing else about
-- themselves. Changes to who-belongs-where are recorded in the audit log.

begin;
create extension if not exists pgtap with schema extensions;

select plan(19);

-- ---------------------------------------------------------------------------------
-- Students, teachers and parents cannot change records
-- ---------------------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub":"30000000-0000-4000-8000-000000000004","role":"authenticated"}', true);
set local role authenticated;

select throws_ok(
  $$ insert into public.enrolments (school_id, class_id, student_profile_id)
     values ('10000000-0000-4000-8000-000000000001', '60000000-0000-4000-8000-000000000002',
             '40000000-0000-4000-8000-000000000004') $$,
  '42501', null,
  'Student cannot add herself to another class'
);
select throws_ok(
  $$ insert into public.school_memberships (school_id, profile_id, role)
     values ('10000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000004', 'school_admin') $$,
  '42501', null,
  'Student cannot make herself a school admin'
);
select results_eq(
  $$ with u as (update public.profiles set preferred_name = 'Mara'
                where id = '40000000-0000-4000-8000-000000000004' returning 1)
     select count(*)::int from u $$,
  $$ values (1) $$,
  'Student can change her own preferred name'
);
select results_eq(
  $$ with u as (update public.profiles set preferred_name = 'Hacked'
                where id = '40000000-0000-4000-8000-000000000003' returning 1)
     select count(*)::int from u $$,
  $$ values (0) $$,
  'Student cannot change her teacher''s preferred name'
);
select throws_ok(
  $$ update public.profiles set full_name = 'Someone Else'
     where id = '40000000-0000-4000-8000-000000000004' $$,
  '42501', null,
  'Student cannot change her own full (official) name'
);

reset role;

select set_config('request.jwt.claims', '{"sub":"30000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
set local role authenticated;

select throws_ok(
  $$ insert into public.classes (school_id, academic_year_id, grade, name)
     values ('10000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001', 10, '10Z') $$,
  '42501', null,
  'Teacher cannot create classes'
);
select results_eq(
  $$ with d as (delete from public.enrolments
                where class_id = '60000000-0000-4000-8000-000000000001' returning 1)
     select count(*)::int from d $$,
  $$ values (0) $$,
  'Teacher cannot remove learners from his class'
);

reset role;

select set_config('request.jwt.claims', '{"sub":"30000000-0000-4000-8000-000000000007","role":"authenticated"}', true);
set local role authenticated;

select results_eq(
  $$ with u as (update public.guardianships set relationship = 'other' returning 1)
     select count(*)::int from u $$,
  $$ values (0) $$,
  'Parent cannot change parent links'
);

reset role;

-- ---------------------------------------------------------------------------------
-- School admins manage their own school only
-- ---------------------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub":"30000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
set local role authenticated;

select lives_ok(
  $$ insert into public.classes (school_id, academic_year_id, grade, name)
     values ('10000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001', 11, '11LSI') $$,
  'Admin can create a class in her school'
);
select lives_ok(
  $$ insert into public.enrolments (school_id, class_id, student_profile_id)
     values ('10000000-0000-4000-8000-000000000001', '60000000-0000-4000-8000-000000000002',
             '40000000-0000-4000-8000-000000000005') $$,
  'Admin can enrol a learner in her school'
);
select throws_ok(
  $$ insert into public.classes (school_id, academic_year_id, grade, name)
     values ('10000000-0000-4000-8000-000000000002', '20000000-0000-4000-8000-000000000002', 10, 'Sneaky') $$,
  '42501', null,
  'Admin cannot create a class in another school'
);
select results_eq(
  $$ with u as (update public.classes set name = 'Renamed'
                where id = '60000000-0000-4000-8000-000000000011' returning 1)
     select count(*)::int from u $$,
  $$ values (0) $$,
  'Admin cannot rename another school''s class'
);
select throws_ok(
  $$ update public.classes set school_id = '10000000-0000-4000-8000-000000000002'
     where id = '60000000-0000-4000-8000-000000000001' $$,
  null, null,
  'Admin cannot move a class into another school'
);
select throws_ok(
  $$ update public.school_memberships set role = 'school_admin'
     where profile_id = '40000000-0000-4000-8000-000000000004' $$,
  '42501', null,
  'Admin cannot change which role a membership is (only add or remove memberships)'
);
select results_eq(
  $$ with u as (update public.school_memberships set status = 'inactive'
                where profile_id = '40000000-0000-4000-8000-000000000008' and role = 'parent' returning 1)
     select count(*)::int from u $$,
  $$ values (1) $$,
  'Admin can deactivate a membership in her school'
);

reset role;

-- ---------------------------------------------------------------------------------
-- The audit log records who made those changes
-- ---------------------------------------------------------------------------------
select is(
  (select count(*)::int from private.audit_log
   where actor_user_id = '30000000-0000-4000-8000-000000000001'
     and table_name in ('classes', 'enrolments', 'school_memberships')),
  3,
  'The admin''s three changes are in the audit log, attributed to her'
);
select is(
  (select count(*)::int from private.audit_log
   where actor_user_id = '30000000-0000-4000-8000-000000000001' and table_name = 'school_memberships'
     and action = 'UPDATE' and old_data ->> 'status' = 'active' and new_data ->> 'status' = 'inactive'),
  1,
  'The audit log keeps the before and after of a change'
);
select is(
  (select array_agg(distinct actor_db_role) from private.audit_log
   where actor_user_id = '30000000-0000-4000-8000-000000000001'),
  array['authenticated'],
  'The audit log records the admin''s changes as an app user, not as the database owner'
);
select is(
  (select array_agg(distinct actor_db_role) from private.audit_log where actor_user_id is null),
  array['postgres'],
  'Changes made directly as the database owner (setup, migrations) are recorded as such'
);

select * from finish();
rollback;
