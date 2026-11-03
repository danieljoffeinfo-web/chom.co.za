-- my_student_dashboard(): the learner home and onboarding's one call.
-- A student gets their own school, year, classes, subjects and saved answers.
-- Teachers, parents and signed-out visitors do not, and nobody sees another school.

begin;
create extension if not exists pgtap with schema extensions;

select plan(15);

-- Amara (10B) has finished onboarding; Liam (10B) has started but not finished.
insert into public.student_study_profiles
  (school_id, academic_year_id, student_profile_id, session_length, study_methods, study_times,
   onboarding_completed_at)
values
  ('10000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001',
   '40000000-0000-4000-8000-000000000004', 'minutes_45', '{past_papers,flashcards}', '{evening}', now()),
  ('10000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001',
   '40000000-0000-4000-8000-000000000005', 'minutes_30', '{videos}', '{afternoon}', null);

insert into public.student_subject_goals
  (school_id, academic_year_id, student_profile_id, subject_id, is_focus, target_percent)
values
  ('10000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001',
   '40000000-0000-4000-8000-000000000004', '50000000-0000-4000-8000-000000000001', true, 75);

-- ---------------------------------------------------------------------------------
-- Amara: student in 10B at Demo High
-- ---------------------------------------------------------------------------------

select set_config('request.jwt.claims', '{"sub":"30000000-0000-4000-8000-000000000004","role":"authenticated"}', true);
set local role authenticated;

select is(
  public.my_student_dashboard() ->> 'school_name', 'Demo High School',
  'A student gets their own school'
);
select is(
  public.my_student_dashboard() ->> 'full_name', 'Amara Nwosu',
  'Her name comes from her profile'
);
select is(
  public.my_student_dashboard() ->> 'year_label', '2026',
  'The current school year is included'
);
select is(
  (public.my_student_dashboard() ->> 'grade')::int, 10,
  'Her grade comes from her class'
);
select is(
  public.my_student_dashboard() -> 'class_names', '["10B"]'::jsonb,
  'She is in 10B'
);
select is(
  (
    select jsonb_agg(s.value ->> 'name' order by s.ordinality)
    from jsonb_array_elements(public.my_student_dashboard() -> 'subjects') with ordinality as s
  ),
  '["English Home Language", "Mathematics"]'::jsonb,
  'Subjects come back once each, sorted by name when the catalogue has no order'
);
select is(
  public.my_student_dashboard() -> 'study_profile' ->> 'session_length', 'minutes_45',
  'Her saved study habits come back in the same call'
);
select is(
  (public.my_student_dashboard() -> 'goals' -> 0 ->> 'target_percent')::int, 75,
  'Her subject goal comes back in the same call'
);
select ok(
  public.my_student_dashboard() -> 'study_profile' ->> 'onboarding_completed_at' is not null,
  'A finished onboarding stays finished'
);
reset role;

-- ---------------------------------------------------------------------------------
-- Liam: started onboarding, has not finished
-- ---------------------------------------------------------------------------------

select set_config('request.jwt.claims', '{"sub":"30000000-0000-4000-8000-000000000005","role":"authenticated"}', true);
set local role authenticated;

select ok(
  (public.my_student_dashboard() -> 'study_profile' ->> 'onboarding_completed_at') is null,
  'An unfinished onboarding comes back unfinished'
);
reset role;

-- ---------------------------------------------------------------------------------
-- Kai: student at the other school
-- ---------------------------------------------------------------------------------

select set_config('request.jwt.claims', '{"sub":"30000000-0000-4000-8000-000000000014","role":"authenticated"}', true);
set local role authenticated;

select is(
  public.my_student_dashboard() ->> 'school_name', 'Other College',
  'A student at another school gets only their own school'
);
select is(
  public.my_student_dashboard() -> 'class_names', '["10LSI"]'::jsonb,
  'and only the class they are in there'
);
reset role;

-- ---------------------------------------------------------------------------------
-- Not a student
-- ---------------------------------------------------------------------------------

select set_config('request.jwt.claims', '{"sub":"30000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
set local role authenticated;
select ok(public.my_student_dashboard() is null, 'A teacher gets nothing');
reset role;

select set_config('request.jwt.claims', '{"sub":"30000000-0000-4000-8000-000000000007","role":"authenticated"}', true);
set local role authenticated;
select ok(public.my_student_dashboard() is null, 'A parent gets nothing');
reset role;

select set_config('request.jwt.claims', '{"role":"anon"}', true);
set local role anon;
select throws_ok(
  $$ select public.my_student_dashboard() $$,
  '42501', null,
  'Signed-out visitors cannot call it'
);
reset role;

select * from finish();
rollback;
