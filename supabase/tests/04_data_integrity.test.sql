-- The database itself refuses impossible data, whoever writes it (even the server).
-- These run as the database owner, which bypasses row-level security, to prove the
-- rules hold at the data level too.

begin;
create extension if not exists pgtap with schema extensions;

select plan(10);

select throws_ok(
  $$ insert into public.enrolments (school_id, class_id, student_profile_id)
     values ('10000000-0000-4000-8000-000000000002', '60000000-0000-4000-8000-000000000011',
             '40000000-0000-4000-8000-000000000004') $$,
  '23503', null,
  'A School A learner cannot be enrolled in a School B class'
);
select throws_ok(
  $$ insert into public.guardianships (school_id, parent_profile_id, student_profile_id)
     values ('10000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000017',
             '40000000-0000-4000-8000-000000000004') $$,
  '23503', null,
  'A parent who doesn''t belong to School A cannot be linked to a School A child'
);
select throws_ok(
  $$ insert into public.teaching_allocations (school_id, class_subject_id, teacher_profile_id)
     values ('10000000-0000-4000-8000-000000000001', '70000000-0000-4000-8000-000000000001',
             '40000000-0000-4000-8000-000000000004') $$,
  '23503', null,
  'A learner cannot be made the teacher of a class'
);
select throws_ok(
  $$ insert into public.classes (school_id, academic_year_id, grade, name)
     values ('10000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000002', 10, '10X') $$,
  '23503', null,
  'A class cannot use another school''s year'
);
select throws_ok(
  $$ insert into public.class_subjects (school_id, class_id, subject_id)
     values ('10000000-0000-4000-8000-000000000001', '60000000-0000-4000-8000-000000000001',
             '50000000-0000-4000-8000-000000000011') $$,
  '23503', null,
  'A class cannot be given another school''s subject'
);
select throws_ok(
  $$ insert into public.academic_years (school_id, label, starts_on, ends_on, curriculum_id, is_current)
     select '10000000-0000-4000-8000-000000000001', '2027', date '2027-01-13', date '2027-12-03', id, true
     from public.curricula where code = 'IEB' $$,
  '23505', null,
  'A school can have only one current year'
);
select throws_ok(
  $$ insert into public.class_subjects (school_id, class_id, subject_id)
     values ('10000000-0000-4000-8000-000000000001', '60000000-0000-4000-8000-000000000001',
             '50000000-0000-4000-8000-000000000001') $$,
  '23505', null,
  'The same subject cannot be added to a class twice'
);
select throws_ok(
  $$ insert into public.classes (school_id, academic_year_id, grade, name)
     values ('10000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001', 13, '13A') $$,
  '23514', null,
  'Grades run from 0 (Grade R) to 12'
);
select throws_ok(
  $$ insert into public.guardianships (school_id, parent_profile_id, student_profile_id)
     values ('10000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000004',
             '40000000-0000-4000-8000-000000000004') $$,
  '23514', null,
  'Nobody can be their own parent'
);
select throws_ok(
  $$ delete from public.schools where id = '10000000-0000-4000-8000-000000000001' $$,
  '23503', null,
  'A school with data cannot be deleted by accident'
);

select * from finish();
rollback;
