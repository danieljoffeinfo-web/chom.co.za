-- Onboarding answers: study habits and subject goals.
-- Only the student can change them; the student, their teachers, their parents and
-- school admins can see them; classmates and other schools cannot.

begin;
create extension if not exists pgtap with schema extensions;

select plan(24);

-- Extra subjects in Amara's class 10B (so she takes 5), plus one she doesn't take.
insert into public.subjects (id, school_id, name) values
  ('50000000-0000-4000-8000-000000000003', '10000000-0000-4000-8000-000000000001', 'History'),
  ('50000000-0000-4000-8000-000000000004', '10000000-0000-4000-8000-000000000001', 'Geography'),
  ('50000000-0000-4000-8000-000000000005', '10000000-0000-4000-8000-000000000001', 'Life Sciences'),
  ('50000000-0000-4000-8000-000000000006', '10000000-0000-4000-8000-000000000001', 'Latin');
insert into public.class_subjects (school_id, class_id, subject_id) values
  ('10000000-0000-4000-8000-000000000001', '60000000-0000-4000-8000-000000000001', '50000000-0000-4000-8000-000000000003'),
  ('10000000-0000-4000-8000-000000000001', '60000000-0000-4000-8000-000000000001', '50000000-0000-4000-8000-000000000004'),
  ('10000000-0000-4000-8000-000000000001', '60000000-0000-4000-8000-000000000001', '50000000-0000-4000-8000-000000000005');

-- ---------------------------------------------------------------------------------
-- Amara (student, 10B) answers onboarding
-- ---------------------------------------------------------------------------------

select set_config('request.jwt.claims', '{"sub":"30000000-0000-4000-8000-000000000004","role":"authenticated"}', true);
set local role authenticated;

select lives_ok(
  $$ insert into public.student_study_profiles
       (school_id, academic_year_id, student_profile_id, session_length, study_methods, study_times)
     values ('10000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001',
             '40000000-0000-4000-8000-000000000004', 'minutes_45',
             '{past_papers,flashcards,ai_chat}', '{evening,weekends}') $$,
  'A student saves her study habits'
);
select lives_ok(
  $$ insert into public.student_subject_goals
       (school_id, academic_year_id, student_profile_id, subject_id, is_focus, target_percent)
     values
       ('10000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001',
        '40000000-0000-4000-8000-000000000004', '50000000-0000-4000-8000-000000000001', true, 75),
       ('10000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001',
        '40000000-0000-4000-8000-000000000004', '50000000-0000-4000-8000-000000000002', true, 70),
       ('10000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001',
        '40000000-0000-4000-8000-000000000004', '50000000-0000-4000-8000-000000000003', true, 65),
       ('10000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001',
        '40000000-0000-4000-8000-000000000004', '50000000-0000-4000-8000-000000000004', false, 60) $$,
  'She sets a target for each subject and picks 3 focus subjects'
);
select throws_ok(
  $$ insert into public.student_subject_goals
       (school_id, academic_year_id, student_profile_id, subject_id, is_focus, target_percent)
     values ('10000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001',
             '40000000-0000-4000-8000-000000000004', '50000000-0000-4000-8000-000000000005', true, 80) $$,
  '23514', null,
  'A 4th focus subject is refused'
);
select throws_ok(
  $$ update public.student_subject_goals set is_focus = true
     where subject_id = '50000000-0000-4000-8000-000000000004' $$,
  '23514', null,
  'Turning a 4th subject into a focus subject is refused too'
);
select lives_ok(
  $$ insert into public.student_subject_goals
       (school_id, academic_year_id, student_profile_id, subject_id, is_focus, target_percent)
     values ('10000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001',
             '40000000-0000-4000-8000-000000000004', '50000000-0000-4000-8000-000000000001', true, 78)
     on conflict (school_id, academic_year_id, student_profile_id, subject_id)
     do update set is_focus = excluded.is_focus, target_percent = excluded.target_percent $$,
  'Re-saving one of her 3 focus subjects (an upsert) is allowed'
);
select lives_ok(
  $$ update public.student_subject_goals set is_focus = false
     where subject_id = '50000000-0000-4000-8000-000000000003';
     update public.student_subject_goals set is_focus = true, target_percent = 68
     where subject_id = '50000000-0000-4000-8000-000000000004' $$,
  'Swapping a focus subject works once one is unpicked'
);
select throws_ok(
  $$ insert into public.student_subject_goals
       (school_id, academic_year_id, student_profile_id, subject_id, target_percent)
     values ('10000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001',
             '40000000-0000-4000-8000-000000000004', '50000000-0000-4000-8000-000000000006', 70) $$,
  '42501', null,
  'She cannot set a goal for a subject she doesn''t take'
);
select throws_ok(
  $$ insert into public.student_subject_goals
       (school_id, academic_year_id, student_profile_id, subject_id, target_percent)
     values ('10000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001',
             '40000000-0000-4000-8000-000000000005', '50000000-0000-4000-8000-000000000001', 70) $$,
  '42501', null,
  'She cannot set goals for a classmate'
);
select throws_ok(
  $$ update public.student_subject_goals set target_percent = 101
     where subject_id = '50000000-0000-4000-8000-000000000001' $$,
  '23514', null,
  'Targets must be between 1 and 100'
);
select throws_ok(
  $$ update public.student_study_profiles set study_methods = '{videos,videos}' $$,
  '23514', null,
  'A study method cannot be picked twice'
);
select lives_ok(
  $$ update public.student_study_profiles set onboarding_completed_at = now() $$,
  'She marks onboarding as finished'
);

reset role;

select is(
  (select count(*)::int from private.audit_log
   where table_name = 'student_subject_goals'
     and new_data ->> 'subject_id' = '50000000-0000-4000-8000-000000000004'),
  2,
  'Every saved change to a goal is kept in the audit log (set, then swapped in as focus)'
);

-- ---------------------------------------------------------------------------------
-- Who can see Amara's answers
-- ---------------------------------------------------------------------------------

create function pg_temp.visible_to(p_user_id text)
returns table (habits int, goals int)
language plpgsql
as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user_id, 'role', 'authenticated')::text, true);
  set local role authenticated;
  return query
    select (select count(*)::int from public.student_study_profiles
            where student_profile_id = '40000000-0000-4000-8000-000000000004'),
           (select count(*)::int from public.student_subject_goals
            where student_profile_id = '40000000-0000-4000-8000-000000000004');
  reset role;
end;
$$;

select results_eq($$ select * from pg_temp.visible_to('30000000-0000-4000-8000-000000000004') $$,
  $$ values (1, 4) $$, 'Amara sees her own answers');
select results_eq($$ select * from pg_temp.visible_to('30000000-0000-4000-8000-000000000002') $$,
  $$ values (1, 4) $$, 'Her Maths teacher sees them');
select results_eq($$ select * from pg_temp.visible_to('30000000-0000-4000-8000-000000000003') $$,
  $$ values (1, 4) $$, 'Her English teacher sees them');
select results_eq($$ select * from pg_temp.visible_to('30000000-0000-4000-8000-000000000007') $$,
  $$ values (1, 4) $$, 'Her parent sees them');
select results_eq($$ select * from pg_temp.visible_to('30000000-0000-4000-8000-000000000001') $$,
  $$ values (1, 4) $$, 'Her school admin sees them');
select results_eq($$ select * from pg_temp.visible_to('30000000-0000-4000-8000-000000000005') $$,
  $$ values (0, 0) $$, 'A classmate does not');
select results_eq($$ select * from pg_temp.visible_to('30000000-0000-4000-8000-000000000008') $$,
  $$ values (0, 0) $$, 'A classmate''s parent does not');
select results_eq($$ select * from pg_temp.visible_to('30000000-0000-4000-8000-000000000011') $$,
  $$ values (0, 0) $$, 'Another school''s admin does not');
select results_eq($$ select * from pg_temp.visible_to('30000000-0000-4000-8000-000000000012') $$,
  $$ values (0, 0) $$, 'Another school''s teacher does not');

-- ---------------------------------------------------------------------------------
-- Only the student can change them
-- ---------------------------------------------------------------------------------

select set_config('request.jwt.claims', '{"sub":"30000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
set local role authenticated;
select results_eq(
  $$ with u as (update public.student_subject_goals set target_percent = 40
                where student_profile_id = '40000000-0000-4000-8000-000000000004' returning 1)
     select count(*)::int from u $$,
  $$ values (0) $$,
  'Her teacher cannot change her goals'
);
reset role;

select set_config('request.jwt.claims', '{"sub":"30000000-0000-4000-8000-000000000007","role":"authenticated"}', true);
set local role authenticated;
select results_eq(
  $$ with u as (update public.student_study_profiles set session_length = 'minutes_60_plus'
                where student_profile_id = '40000000-0000-4000-8000-000000000004' returning 1)
     select count(*)::int from u $$,
  $$ values (0) $$,
  'Her parent cannot change her study habits'
);
reset role;

select set_config('request.jwt.claims', '{"role":"anon"}', true);
set local role anon;
select throws_ok(
  $$ select 1 from public.student_subject_goals $$,
  '42501', null,
  'Signed-out visitors cannot read goals at all'
);
reset role;

select * from finish();
rollback;
