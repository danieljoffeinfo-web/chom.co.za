-- School isolation: nobody sees anything from a school they don't belong to.
-- Uses the two fake schools in supabase/seed.sql.

begin;
create extension if not exists pgtap with schema extensions;

select plan(22);

-- ---------------------------------------------------------------------------------
-- Grace, admin of School B, sees nothing of School A
-- ---------------------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub":"30000000-0000-4000-8000-000000000011","role":"authenticated"}', true);
set local role authenticated;

select is((select count(*)::int from public.schools where id = '10000000-0000-4000-8000-000000000001'), 0, 'B admin: cannot see School A');
select is((select count(*)::int from public.academic_years where school_id = '10000000-0000-4000-8000-000000000001'), 0, 'B admin: no School A years');
select is((select count(*)::int from public.subjects where school_id = '10000000-0000-4000-8000-000000000001'), 0, 'B admin: no School A subjects');
select is((select count(*)::int from public.classes where school_id = '10000000-0000-4000-8000-000000000001'), 0, 'B admin: no School A classes');
select is((select count(*)::int from public.class_subjects where school_id = '10000000-0000-4000-8000-000000000001'), 0, 'B admin: no School A class subjects');
select is((select count(*)::int from public.teaching_allocations where school_id = '10000000-0000-4000-8000-000000000001'), 0, 'B admin: no School A teaching');
select is((select count(*)::int from public.enrolments where school_id = '10000000-0000-4000-8000-000000000001'), 0, 'B admin: no School A enrolments');
select is((select count(*)::int from public.school_memberships where school_id = '10000000-0000-4000-8000-000000000001'), 0, 'B admin: no School A memberships');
select is((select count(*)::int from public.guardianships where school_id = '10000000-0000-4000-8000-000000000001'), 0, 'B admin: no School A guardianships');
select is((select count(*)::int from public.profiles where id = '40000000-0000-4000-8000-000000000004'), 0, 'B admin: cannot see Amara (School A learner)');

reset role;

-- ---------------------------------------------------------------------------------
-- Thandi, admin of School A, sees nothing of School B
-- ---------------------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub":"30000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
set local role authenticated;

select is((select count(*)::int from public.schools where id = '10000000-0000-4000-8000-000000000002'), 0, 'A admin: cannot see School B');
select is((select count(*)::int from public.classes where school_id = '10000000-0000-4000-8000-000000000002'), 0, 'A admin: no School B classes');
select is((select count(*)::int from public.enrolments where school_id = '10000000-0000-4000-8000-000000000002'), 0, 'A admin: no School B enrolments');
select is((select count(*)::int from public.school_memberships where school_id = '10000000-0000-4000-8000-000000000002'), 0, 'A admin: no School B memberships');
select is((select count(*)::int from public.profiles where id = '40000000-0000-4000-8000-000000000014'), 0, 'A admin: cannot see Kai (School B learner)');

reset role;

-- ---------------------------------------------------------------------------------
-- A signed-in person with no profile or membership sees no school data
-- ---------------------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub":"99999999-0000-4000-8000-000000000099","role":"authenticated"}', true);
set local role authenticated;

select is((select count(*)::int from public.schools), 0, 'Stranger: no schools');
select is((select count(*)::int from public.profiles), 0, 'Stranger: no people');
select is((select count(*)::int from public.classes), 0, 'Stranger: no classes');
select is((select count(*)::int from public.curricula), 1, 'Stranger: can read the curriculum list (shared reference data)');

reset role;

-- ---------------------------------------------------------------------------------
-- Signed-out visitors are refused outright
-- ---------------------------------------------------------------------------------
select set_config('request.jwt.claims', '{"role":"anon"}', true);
set local role anon;

select throws_ok('select * from public.schools', '42501', null, 'Signed out: schools refused');
select throws_ok('select * from public.profiles', '42501', null, 'Signed out: people refused');
select throws_ok('select * from public.curricula', '42501', null, 'Signed out: even reference data refused');

reset role;

select * from finish();
rollback;
