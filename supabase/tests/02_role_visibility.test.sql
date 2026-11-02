-- What each kind of person can see inside their own school.
-- Expected numbers come from the fake data in supabase/seed.sql:
--   School A classes: 10B (Maths: Sizwe; English: Priya), 10C (English: Priya)
--   10B: Amara, Liam   10C: Zoe, Sipho
--   Parents: Ngozi -> Amara (and Kai at School B), Pieter -> Liam, Sizwe -> Zoe

begin;
create extension if not exists pgtap with schema extensions;

select plan(52);

-- ---------------------------------------------------------------------------------
-- Amara, student in 10B: her class, her teachers, her parent. Not her classmates.
-- ---------------------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub":"30000000-0000-4000-8000-000000000004","role":"authenticated"}', true);
set local role authenticated;

select is((select count(*)::int from public.schools), 1, 'Student: sees her school');
select is((select count(*)::int from public.subjects), 2, 'Student: sees her school''s subjects');
select is((select count(*)::int from public.classes), 1, 'Student: sees only her class');
select is((select count(*)::int from public.class_subjects), 2, 'Student: sees her class''s two subjects');
select is((select count(*)::int from public.teaching_allocations), 2, 'Student: sees who teaches her class');
select is((select count(*)::int from public.enrolments), 1, 'Student: sees only her own enrolment, not classmates''');
select is((select count(*)::int from public.school_memberships), 1, 'Student: sees only her own membership');
select is((select count(*)::int from public.guardianships), 1, 'Student: sees her own parent link');
select is((select count(*)::int from public.profiles), 4, 'Student: sees herself, her two teachers and her mother');
select is((select count(*)::int from public.profiles where id = '40000000-0000-4000-8000-000000000005'), 0, 'Student: cannot see classmate Liam');

reset role;

-- ---------------------------------------------------------------------------------
-- Liam, Amara's classmate: also cannot see Amara.
-- ---------------------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub":"30000000-0000-4000-8000-000000000005","role":"authenticated"}', true);
set local role authenticated;

select is((select count(*)::int from public.profiles where id = '40000000-0000-4000-8000-000000000004'), 0, 'Student: cannot see classmate Amara');
select is((select count(*)::int from public.profiles), 4, 'Student: sees himself, his two teachers and his father');

reset role;

-- ---------------------------------------------------------------------------------
-- Priya, teacher of English in 10B and 10C.
-- ---------------------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub":"30000000-0000-4000-8000-000000000003","role":"authenticated"}', true);
set local role authenticated;

select is((select count(*)::int from public.classes), 2, 'Teacher: sees the two classes she teaches');
select is((select count(*)::int from public.class_subjects), 3, 'Teacher: sees all subjects in her classes');
select is((select count(*)::int from public.enrolments), 4, 'Teacher: sees the four learners in her classes');
select is((select count(*)::int from public.guardianships), 3, 'Teacher: sees parent links for her learners');
select is((select count(*)::int from public.profiles), 8, 'Teacher: sees herself, 4 learners and their 3 parents');
select is((select count(*)::int from public.school_memberships), 1, 'Teacher: sees only her own membership');
select is(
  (select count(*)::int from public.profiles where id = '40000000-0000-4000-8000-000000000009'),
  1,
  'Teacher: sees Sipho, a learner who has never signed in'
);

reset role;

-- ---------------------------------------------------------------------------------
-- Sizwe: teaches Maths in 10B AND is Zoe's father (Zoe is in 10C). Both roles apply.
-- ---------------------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub":"30000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
set local role authenticated;

select is((select count(*)::int from public.classes), 2, 'Teacher-parent: sees the class he teaches and his child''s class');
select is((select count(*)::int from public.enrolments), 3, 'Teacher-parent: sees his 2 learners and his own child, not Sipho');
select is(
  (select count(*)::int from public.enrolments where student_profile_id = '40000000-0000-4000-8000-000000000009'),
  0,
  'Teacher-parent: cannot see Sipho, who is in his child''s class but not his'
);
select is((select count(*)::int from public.school_memberships), 2, 'Teacher-parent: sees both of his memberships');
select is((select count(*)::int from public.guardianships), 3, 'Teacher-parent: his own link plus links for his learners');
select is((select count(*)::int from public.profiles), 7, 'Teacher-parent: himself, 2 learners, their parents, his child, her teacher');

reset role;

-- ---------------------------------------------------------------------------------
-- Ngozi: parent of Amara (School A) and of Kai (School B).
-- ---------------------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub":"30000000-0000-4000-8000-000000000007","role":"authenticated"}', true);
set local role authenticated;

select is((select count(*)::int from public.schools), 2, 'Parent: sees both of her children''s schools');
select is((select count(*)::int from public.classes), 2, 'Parent: sees only her children''s classes');
select is((select count(*)::int from public.enrolments), 2, 'Parent: sees only her children''s enrolments');
select is(
  (select count(*)::int from public.enrolments where student_profile_id = '40000000-0000-4000-8000-000000000005'),
  0,
  'Parent: cannot see Liam, who is in her daughter''s class'
);
select is((select count(*)::int from public.guardianships), 2, 'Parent: sees her own two parent links, not the other parent''s');
select is((select count(*)::int from public.profiles), 6, 'Parent: herself, 2 children, and their 3 teachers');
select is((select count(*)::int from public.school_memberships), 2, 'Parent: sees her own two memberships');

reset role;

-- ---------------------------------------------------------------------------------
-- Thandi, admin of School A: everything in her school.
-- ---------------------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub":"30000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
set local role authenticated;

select is((select count(*)::int from public.schools), 1, 'Admin: sees her school');
select is((select count(*)::int from public.academic_years), 1, 'Admin: sees her school''s year');
select is((select count(*)::int from public.subjects), 2, 'Admin: sees all subjects');
select is((select count(*)::int from public.classes), 2, 'Admin: sees all classes');
select is((select count(*)::int from public.class_subjects), 3, 'Admin: sees all class subjects');
select is((select count(*)::int from public.teaching_allocations), 3, 'Admin: sees all teaching');
select is((select count(*)::int from public.enrolments), 4, 'Admin: sees all enrolments');
select is((select count(*)::int from public.school_memberships), 10, 'Admin: sees every membership in her school');
select is((select count(*)::int from public.guardianships), 3, 'Admin: sees every parent link in her school');
select is((select count(*)::int from public.profiles), 9, 'Admin: sees every person in her school');

reset role;

-- ---------------------------------------------------------------------------------
-- John, teacher at School B: his one class.
-- ---------------------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub":"30000000-0000-4000-8000-000000000012","role":"authenticated"}', true);
set local role authenticated;

select is((select count(*)::int from public.classes), 1, 'School B teacher: sees his class 10LSI');
select is((select name from public.classes), '10LSI', 'Free-text class names work');
select is((select count(*)::int from public.profiles), 4, 'School B teacher: himself, Kai and Kai''s two parents');

reset role;

-- ---------------------------------------------------------------------------------
-- Deactivating a membership removes access immediately.
-- ---------------------------------------------------------------------------------
update public.school_memberships
set status = 'inactive'
where profile_id = '40000000-0000-4000-8000-000000000008' and role = 'parent';

select set_config('request.jwt.claims', '{"sub":"30000000-0000-4000-8000-000000000008","role":"authenticated"}', true);
set local role authenticated;

select is((select count(*)::int from public.schools), 0, 'Inactive parent: no longer sees the school');
select is((select count(*)::int from public.enrolments), 0, 'Inactive parent: no longer sees his child''s enrolment');
select is((select count(*)::int from public.classes), 0, 'Inactive parent: no longer sees his child''s class');
select is((select count(*)::int from public.profiles), 1, 'Inactive parent: sees only himself');

reset role;

-- ---------------------------------------------------------------------------------
-- Zoe, student in 10C: sees her father Sizwe as her parent, not as a teacher.
-- ---------------------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub":"30000000-0000-4000-8000-000000000006","role":"authenticated"}', true);
set local role authenticated;

select is((select count(*)::int from public.classes), 1, 'Student 10C: sees only 10C');
select is((select count(*)::int from public.profiles), 3, 'Student 10C: herself, her teacher and her father');
select is((select count(*)::int from public.teaching_allocations), 1, 'Student 10C: sees only 10C''s teaching');

reset role;

select * from finish();
rollback;
