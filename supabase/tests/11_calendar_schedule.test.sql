-- Calendars and the curriculum schedule: the units are complete and ordered, Styfe's
-- schedule lands only on teaching days and in order, Grade 12 content ends before
-- prelims, pinned units survive regeneration, and only the school can see it all.

begin;
create extension if not exists pgtap with schema extensions;

select plan(20);
set local client_min_messages = warning;

-- ---------------------------------------------------------------------------------
-- Curriculum units (reference data)
-- ---------------------------------------------------------------------------------

select is((select count(*)::int from public.curriculum_units), 455, 'All 455 curriculum units from the brief are loaded');

select is(
  (select count(distinct (curriculum_subject_id, grade))::int from public.curriculum_units),
  58,
  '18 subjects in Grades 10-12, plus Further Studies Maths and English in Grades 11-12'
);

select is_empty(
  $$ select curriculum_subject_id, grade from public.curriculum_units
     group by curriculum_subject_id, grade having max(position) <> count(*) $$,
  'Every subject''s units are numbered 1, 2, 3 ... with no gaps'
);

select results_eq(
  $$ select cu.title, cu.teaching_weeks::int from public.curriculum_units cu
     join public.curriculum_subjects cs on cs.id = cu.curriculum_subject_id
     where cs.name = 'Mathematics' and cu.grade = 11 and cu.position in (1, 12) order by cu.position $$,
  $$ values ('Exponents and surds', 3), ('Statistics', 3) $$,
  'Grade 11 Maths starts with exponents and surds and ends with statistics'
);

-- ---------------------------------------------------------------------------------
-- Styfe's calendar and schedule
-- ---------------------------------------------------------------------------------

select lives_ok($$ select private.demo_load_styfe() $$, 'Styfe loads with its calendar and schedule');

create temp view styfe_schedule as
select us.*, cu.curriculum_subject_id, cu.grade, cu.position, cu.is_ongoing
from public.unit_schedules us
join public.curriculum_units cu on cu.id = us.curriculum_unit_id
join public.schools s on s.id = us.school_id and s.slug = 'styfe';

select results_eq(
  $$ select t.term_number::int, t.starts_on, t.ends_on from public.school_terms t
     join public.schools s on s.id = t.school_id and s.slug = 'styfe' order by 1 $$,
  $$ values (1, '2026-01-14'::date, '2026-04-10'::date), (2, '2026-05-06'::date, '2026-08-07'::date),
            (3, '2026-09-09'::date, '2026-12-04'::date) $$,
  'Styfe runs three terms'
);

select is(
  public.school_today((select id from public.schools where slug = 'styfe')),
  '2026-11-07'::date,
  'Styfe''s today is fixed at 7 November 2026'
);

select is(
  public.school_today((select id from public.schools where not is_demo limit 1)),
  (now() at time zone 'Africa/Johannesburg')::date,
  'A real school''s today is today in South Africa'
);

select is(
  (select count(*)::int from styfe_schedule),
  (select count(*)::int from public.curriculum_units cu
   join public.subjects s on s.curriculum_subject_id = cu.curriculum_subject_id
   join public.schools sc on sc.id = s.school_id and sc.slug = 'styfe'
   join public.subject_offerings o on o.subject_id = s.id
   where cu.grade between o.min_grade and o.max_grade),
  'Every unit of every subject Styfe offers is scheduled'
);

select is_empty(
  $$ select s.id from styfe_schedule s
     where s.starts_on not in (select private.teaching_days(s.academic_year_id, s.grade))
        or s.ends_on not in (select private.teaching_days(s.academic_year_id, s.grade)) $$,
  'Every unit starts and ends on a teaching day (in term, not a holiday, half-term or exam)'
);

select is_empty(
  $$ select a.id from styfe_schedule a
     join styfe_schedule b on b.curriculum_subject_id = a.curriculum_subject_id and b.grade = a.grade
      and b.position = a.position + 1 and not a.is_ongoing and not b.is_ongoing
     where b.starts_on <= a.ends_on $$,
  'Within a subject, each unit starts after the one before it ends'
);

select is_empty(
  $$ select s.id from styfe_schedule s
     join public.school_terms t on t.academic_year_id = s.academic_year_id and t.term_number = s.term_number
     where s.starts_on not between t.starts_on and t.ends_on $$,
  'Each unit records the term it starts in'
);

select ok(
  (select max(ends_on) from styfe_schedule where grade = 12)
    < (select e.starts_on from public.exam_windows e
       join public.schools s on s.id = e.school_id and s.slug = 'styfe' where e.kind = 'preliminary'),
  'Grade 12 content ends before the preliminary exams'
);

select results_eq(
  $$ select grade::int, min(starts_on), max(ends_on) from styfe_schedule where grade < 12 group by grade order by grade $$,
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
  and us.school_id = (select id from public.schools where slug = 'styfe');

select private.generate_unit_schedule((select y.id from public.academic_years y
  join public.schools s on s.id = y.school_id and s.slug = 'styfe' where y.is_current));

select results_eq(
  $$ select s.starts_on, s.ends_on, s.is_pinned from styfe_schedule s
     join public.curriculum_units cu on cu.id = s.curriculum_unit_id
     join public.curriculum_subjects cs on cs.id = cu.curriculum_subject_id
     where cs.name = 'Mathematics' and s.grade = 11 and cu.title = 'Probability' $$,
  $$ values ('2026-10-12'::date, '2026-10-16'::date, true) $$,
  'A pinned unit keeps its dates when the schedule is regenerated'
);

select is_empty(
  $$ select s.id from styfe_schedule s
     join public.curriculum_subjects cs on cs.id = s.curriculum_subject_id
     where cs.name = 'Mathematics' and s.grade = 11 and not s.is_pinned
       and (s.starts_on between '2026-10-12' and '2026-10-16' or s.ends_on between '2026-10-12' and '2026-10-16') $$,
  'The other units no longer start or end on the pinned days'
);

-- ---------------------------------------------------------------------------------
-- Who can see it
-- ---------------------------------------------------------------------------------

-- David signs in.
insert into auth.users (id, email, email_confirmed_at)
values ('30000000-0000-4000-8000-0000000000d1', 'david@styfe.co.za', now());
update public.profiles p set user_id = '30000000-0000-4000-8000-0000000000d1'
from public.school_memberships m
where m.profile_id = p.id and m.email = 'david@styfe.co.za';

select set_config('request.jwt.claims', '{"sub":"30000000-0000-4000-8000-0000000000d1","role":"authenticated"}', true);
set local role authenticated;
select results_eq(
  $$ select (select count(*)::int from public.school_terms),
            (select count(*)::int from public.exam_windows),
            (select count(*) > 400 from public.unit_schedules),
            public.school_today((select school_id from public.school_terms limit 1)) $$,
  $$ values (3, 4, true, '2026-11-07'::date) $$,
  'A Styfe learner sees the school''s terms, exam windows and schedule, and its demo date'
);
reset role;

select set_config('request.jwt.claims', '{"sub":"30000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
set local role authenticated;
select results_eq(
  $$ select (select count(*)::int from public.school_terms),
            (select count(*)::int from public.unit_schedules),
            (select count(*)::int from public.school_calendar_breaks) $$,
  $$ values (0, 0, 0) $$,
  'Another school''s admin sees none of Styfe''s calendar or schedule'
);
reset role;

select ok(
  not has_function_privilege('authenticated', 'private.generate_unit_schedule(uuid)', 'EXECUTE')
  and not has_function_privilege('authenticated', 'private.demo_load_styfe_calendar(uuid)', 'EXECUTE')
  and not has_function_privilege('authenticated', 'private.demo_load_styfe_roster(jsonb)', 'EXECUTE')
  and not has_function_privilege('authenticated', 'private.teaching_days(uuid, integer)', 'EXECUTE'),
  'Nobody signed in can regenerate a schedule or run the demo loaders'
);

select private.demo_remove_school('styfe');
select ok(
  not exists (select 1 from public.unit_schedules)
  and not exists (select 1 from public.school_terms)
  and not exists (select 1 from public.exam_windows),
  'Removing Styfe removes its calendar and schedule too'
);

select * from finish();
rollback;
