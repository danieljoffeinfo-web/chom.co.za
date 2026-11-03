-- my_staff_dashboard(): the staff dashboard's one call.
-- Teachers get their own school, roles and the subjects they teach with counts;
-- admins who teach nothing get an empty list; students, parents and signed-out
-- visitors get nothing; nobody sees another school.

begin;
create extension if not exists pgtap with schema extensions;

select plan(16);

-- Amara (10B) has finished onboarding this year; Liam (10B) has started but not finished.
insert into public.student_study_profiles
  (school_id, academic_year_id, student_profile_id, session_length, study_methods, study_times,
   onboarding_completed_at)
values
  ('10000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001',
   '40000000-0000-4000-8000-000000000004', 'minutes_45', '{past_papers}', '{evening}', now()),
  ('10000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001',
   '40000000-0000-4000-8000-000000000005', 'minutes_30', '{videos}', '{afternoon}', null);

-- ---------------------------------------------------------------------------------
-- Sizwe: teacher (Maths 10B) and a parent at Demo High
-- ---------------------------------------------------------------------------------

select set_config('request.jwt.claims', '{"sub":"30000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
set local role authenticated;

select is(
  public.my_staff_dashboard() ->> 'school_name', 'Demo High School',
  'A teacher gets their own school'
);
select is(
  public.my_staff_dashboard() -> 'roles', '["teacher"]'::jsonb,
  'Only staff roles are listed (not his parent role)'
);
select is(
  public.my_staff_dashboard() ->> 'year_label', '2026',
  'The current school year is included'
);
select is(
  jsonb_array_length(public.my_staff_dashboard() -> 'classes'), 1,
  'He teaches one subject'
);
select is(
  ((public.my_staff_dashboard() -> 'classes' -> 0) - 'class_subject_id') - 'class_id',
  '{"class_name":"10B","grade":10,"subject_name":"Mathematics","learners":2,"onboarded":1}'::jsonb,
  'Maths 10B: 2 learners, 1 of them has finished onboarding'
);
reset role;

-- ---------------------------------------------------------------------------------
-- Priya: teaches English to 10B and 10C
-- ---------------------------------------------------------------------------------

select set_config('request.jwt.claims', '{"sub":"30000000-0000-4000-8000-000000000003","role":"authenticated"}', true);
set local role authenticated;

select is(
  (select jsonb_agg(c ->> 'class_name') from jsonb_array_elements(public.my_staff_dashboard() -> 'classes') c),
  '["10B", "10C"]'::jsonb,
  'Classes come back sorted by grade and class name'
);
select is(
  (public.my_staff_dashboard() -> 'classes' -> 1 ->> 'learners')::int, 2,
  '10C counts its learners, including one who has never signed in'
);
select is(
  (public.my_staff_dashboard() -> 'classes' -> 1 ->> 'onboarded')::int, 0,
  'Nobody in 10C has onboarded'
);
reset role;

-- ---------------------------------------------------------------------------------
-- Thandi: school admin who teaches nothing
-- ---------------------------------------------------------------------------------

select set_config('request.jwt.claims', '{"sub":"30000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
set local role authenticated;

select is(
  public.my_staff_dashboard() -> 'roles', '["school_admin"]'::jsonb,
  'A school admin gets in as an admin'
);
select is(
  public.my_staff_dashboard() -> 'classes', '[]'::jsonb,
  'An admin who teaches nothing gets an empty class list'
);
reset role;

-- ---------------------------------------------------------------------------------
-- John: teacher at the other school
-- ---------------------------------------------------------------------------------

select set_config('request.jwt.claims', '{"sub":"30000000-0000-4000-8000-000000000012","role":"authenticated"}', true);
set local role authenticated;

select is(
  public.my_staff_dashboard() ->> 'school_name', 'Other College',
  'A teacher at another school gets only their own school'
);
select is(
  (select jsonb_agg(c ->> 'class_name') from jsonb_array_elements(public.my_staff_dashboard() -> 'classes') c),
  '["10LSI"]'::jsonb,
  'and only the classes they teach there'
);
reset role;

-- ---------------------------------------------------------------------------------
-- Not staff
-- ---------------------------------------------------------------------------------

select set_config('request.jwt.claims', '{"sub":"30000000-0000-4000-8000-000000000004","role":"authenticated"}', true);
set local role authenticated;
select ok(public.my_staff_dashboard() is null, 'A student gets nothing');
reset role;

select set_config('request.jwt.claims', '{"sub":"30000000-0000-4000-8000-000000000007","role":"authenticated"}', true);
set local role authenticated;
select ok(public.my_staff_dashboard() is null, 'A parent gets nothing');
reset role;

select set_config('request.jwt.claims', '{"sub":"30000000-0000-4000-8000-000000000099","role":"authenticated"}', true);
set local role authenticated;
select ok(public.my_staff_dashboard() is null, 'A login with no profile gets nothing');
reset role;

select set_config('request.jwt.claims', '{"role":"anon"}', true);
set local role anon;
select throws_ok(
  $$ select public.my_staff_dashboard() $$,
  '42501', null,
  'Signed-out visitors cannot call it'
);
reset role;

select * from finish();
rollback;
