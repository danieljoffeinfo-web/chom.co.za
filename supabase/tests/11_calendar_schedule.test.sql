-- Calendars and the curriculum schedule: the units are complete and ordered, a
-- school's schedule lands only on teaching days and in order, Grade 12 content ends
-- before prelims, pinned units survive regeneration, and only the school can see it.

begin;
create extension if not exists pgtap with schema extensions;

select plan(15);
set local client_min_messages = warning;

-- ---------------------------------------------------------------------------------
-- Curriculum units (reference data): cleared, so this test brings its own
-- ---------------------------------------------------------------------------------

select is((select count(*)::int from public.curriculum_units), 0, 'No curriculum units are loaded');

-- Four units for Mathematics and English Home Language in each of Grades 10-12;
-- Grade 11 Maths has Probability third.
insert into public.curriculum_units (curriculum_id, curriculum_subject_id, grade, position, title, teaching_weeks)
select cs.curriculum_id, cs.id, g.grade, u.position,
       case when cs.name = 'Mathematics' and g.grade = 11 and u.position = 3 then 'Probability'
            else cs.name || ' unit ' || u.position end,
       u.weeks
from public.curriculum_subjects cs
join public.curricula c on c.id = cs.curriculum_id and c.code = 'IEB'
cross join (values (10), (11), (12)) as g (grade)
cross join (values (1, 4.0), (2, 3.0), (3, 3.0), (4, 2.0)) as u (position, weeks)
where cs.name in ('Mathematics', 'English Home Language');

-- ---------------------------------------------------------------------------------
-- A school's calendar and schedule (the test school, A: Maths and English, Grades 10-12)
-- ---------------------------------------------------------------------------------

update public.subjects s
set curriculum_subject_id = cs.id
from public.curriculum_subjects cs
where s.school_id = '10000000-0000-4000-8000-000000000001' and cs.name = s.name;

insert into public.subject_offerings (school_id, academic_year_id, subject_id, kind, min_grade, max_grade)
select s.school_id, '20000000-0000-4000-8000-000000000001', s.id, 'fundamental', 10, 12
from public.subjects s where s.school_id = '10000000-0000-4000-8000-000000000001';

-- A 3-term 2026 calendar (ISASA Central Region guidelines).
insert into public.school_terms (school_id, academic_year_id, term_number, starts_on, ends_on) values
  ('10000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001', 1, '2026-01-14', '2026-04-10'),
  ('10000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001', 2, '2026-05-06', '2026-08-07'),
  ('10000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001', 3, '2026-09-09', '2026-12-04');

insert into public.school_calendar_breaks (school_id, academic_year_id, kind, label, starts_on, ends_on) values
  ('10000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001', 'half_term', 'Term 1 half-term', '2026-02-20', '2026-02-23'),
  ('10000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001', 'school_holiday', 'Youth Day long weekend', '2026-06-15', '2026-06-15'),
  ('10000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001', 'half_term', 'Term 2 half-term', '2026-06-29', '2026-07-03'),
  ('10000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001', 'school_holiday', 'Heritage Day long weekend', '2026-09-25', '2026-09-25'),
  ('10000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001', 'half_term', 'Term 3 half-term', '2026-10-23', '2026-10-26');

insert into public.exam_windows
  (school_id, academic_year_id, kind, label, min_grade, max_grade, starts_on, ends_on, is_approximate) values
  ('10000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001', 'mid_year', 'Mid-year exams', 10, 12, '2026-06-01', '2026-06-19', false),
  ('10000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001', 'preliminary', 'Grade 12 preliminary exams', 12, 12, '2026-07-20', '2026-08-06', false),
  ('10000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001', 'final_external', 'IEB NSC final exams', 12, 12, '2026-10-13', '2026-11-26', true),
  ('10000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001', 'final_internal', 'Grade 10-11 final exams', 10, 11, '2026-11-09', '2026-11-27', false);

insert into public.grade_content_end_dates (school_id, academic_year_id, grade, content_ends_on) values
  ('10000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001', 10, '2026-10-30'),
  ('10000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001', 11, '2026-10-30'),
  ('10000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001', 12, '2026-07-17');

select ok(
  private.generate_unit_schedule('20000000-0000-4000-8000-000000000001') > 0,
  'The school''s schedule is generated'
);

create temp view school_schedule as
select us.*, cu.curriculum_subject_id, cu.grade, cu.position, cu.is_ongoing
from public.unit_schedules us
join public.curriculum_units cu on cu.id = us.curriculum_unit_id
where us.school_id = '10000000-0000-4000-8000-000000000001';

select is(
  public.school_today('10000000-0000-4000-8000-000000000001'),
  (now() at time zone 'Africa/Johannesburg')::date,
  'A school''s today is today in South Africa'
);

select is(
  (select count(*)::int from school_schedule),
  (select count(*)::int from public.curriculum_units cu
   join public.subjects s on s.curriculum_subject_id = cu.curriculum_subject_id
   join public.subject_offerings o on o.subject_id = s.id
   where s.school_id = '10000000-0000-4000-8000-000000000001'
     and cu.grade between o.min_grade and o.max_grade),
  'Every unit of every subject the school offers is scheduled'
);

select is_empty(
  $$ select s.id from school_schedule s
     where s.starts_on not in (select private.teaching_days(s.academic_year_id, s.grade))
        or s.ends_on not in (select private.teaching_days(s.academic_year_id, s.grade)) $$,
  'Every unit starts and ends on a teaching day (in term, not a holiday, half-term or exam)'
);

select is_empty(
  $$ select a.id from school_schedule a
     join school_schedule b on b.curriculum_subject_id = a.curriculum_subject_id and b.grade = a.grade
      and b.position = a.position + 1 and not a.is_ongoing and not b.is_ongoing
     where b.starts_on <= a.ends_on $$,
  'Within a subject, each unit starts after the one before it ends'
);

select is_empty(
  $$ select s.id from school_schedule s
     join public.school_terms t on t.academic_year_id = s.academic_year_id and t.term_number = s.term_number
     where s.starts_on not between t.starts_on and t.ends_on $$,
  'Each unit records the term it starts in'
);

select ok(
  (select max(ends_on) from school_schedule where grade = 12)
    < (select e.starts_on from public.exam_windows e
       where e.school_id = '10000000-0000-4000-8000-000000000001' and e.kind = 'preliminary'),
  'Grade 12 content ends before the preliminary exams'
);

select results_eq(
  $$ select grade::int, min(starts_on), max(ends_on) from school_schedule where grade < 12 group by grade order by grade $$,
  $$ values (10, '2026-01-14'::date, '2026-10-30'::date), (11, '2026-01-14'::date, '2026-10-30'::date) $$,
  'Grades 10-11 run from the first day of school to their content-end date'
);

-- A teacher pins Grade 11 Maths "Probability" to 12-16 October; regenerating keeps it
-- and moves the other units off those days.
update public.unit_schedules us
set starts_on = '2026-10-12', ends_on = '2026-10-16', is_pinned = true
from public.curriculum_units cu, public.curriculum_subjects cs
where cu.id = us.curriculum_unit_id and cs.id = cu.curriculum_subject_id
  and cs.name = 'Mathematics' and cu.grade = 11 and cu.title = 'Probability'
  and us.school_id = '10000000-0000-4000-8000-000000000001';

select private.generate_unit_schedule('20000000-0000-4000-8000-000000000001');

select results_eq(
  $$ select s.starts_on, s.ends_on, s.is_pinned from school_schedule s
     join public.curriculum_units cu on cu.id = s.curriculum_unit_id
     join public.curriculum_subjects cs on cs.id = cu.curriculum_subject_id
     where cs.name = 'Mathematics' and s.grade = 11 and cu.title = 'Probability' $$,
  $$ values ('2026-10-12'::date, '2026-10-16'::date, true) $$,
  'A pinned unit keeps its dates when the schedule is regenerated'
);

select is_empty(
  $$ select s.id from school_schedule s
     join public.curriculum_subjects cs on cs.id = s.curriculum_subject_id
     where cs.name = 'Mathematics' and s.grade = 11 and not s.is_pinned
       and (s.starts_on between '2026-10-12' and '2026-10-16' or s.ends_on between '2026-10-12' and '2026-10-16') $$,
  'The other units no longer start or end on the pinned days'
);

-- ---------------------------------------------------------------------------------
-- Who can see it
-- ---------------------------------------------------------------------------------

-- Amara, a student at the school.
select set_config('request.jwt.claims', '{"sub":"30000000-0000-4000-8000-000000000004","role":"authenticated"}', true);
set local role authenticated;
select results_eq(
  $$ select (select count(*)::int from public.school_terms),
            (select count(*)::int from public.exam_windows),
            (select count(*) > 0 from public.unit_schedules) $$,
  $$ values (3, 4, true) $$,
  'A learner sees her school''s terms, exam windows and schedule'
);
reset role;

-- Grace, the admin of the other school.
select set_config('request.jwt.claims', '{"sub":"30000000-0000-4000-8000-000000000011","role":"authenticated"}', true);
set local role authenticated;
select results_eq(
  $$ select (select count(*)::int from public.school_terms),
            (select count(*)::int from public.unit_schedules),
            (select count(*)::int from public.school_calendar_breaks) $$,
  $$ values (0, 0, 0) $$,
  'Another school''s admin sees none of its calendar or schedule'
);
reset role;

select ok(
  not has_function_privilege('authenticated', 'private.generate_unit_schedule(uuid)', 'EXECUTE')
  and not has_function_privilege('authenticated', 'private.teaching_days(uuid, integer)', 'EXECUTE'),
  'Nobody signed in can regenerate a schedule'
);

select ok(
  to_regprocedure('private.demo_load_styfe(jsonb)') is null
  and to_regprocedure('private.demo_remove_school(text)') is null
  and not exists (select 1 from information_schema.columns
                  where table_schema = 'public' and table_name = 'schools'
                    and column_name in ('is_demo', 'demo_today')),
  'There are no demo schools: no generator, no remover, no demo columns'
);

select * from finish();
rollback;
