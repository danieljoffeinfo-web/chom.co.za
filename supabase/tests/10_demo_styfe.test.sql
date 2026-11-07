-- The Styfe demo school: the demo data brief's roster checks (section 9), plus the
-- demo plumbing: reloading gives the same people, removal is complete, real schools
-- can't be removed, and the new subject set-up tables stay inside their school.

begin;
create extension if not exists pgtap with schema extensions;

select plan(31);
set local client_min_messages = warning;

select lives_ok(
  $$ select private.demo_load_styfe('{"maths_teacher": "Dan@Styfe.co.za", "thando_parent": "login@example.org"}') $$,
  'Styfe loads'
);

-- Learners at Styfe with the subjects they take (through any of their classes).
create temp view styfe_takes as
select m.profile_id, s.id as subject_id, s.name as subject, o.kind, o.block, o.min_grade, o.max_grade,
       (select c2.grade::int from public.enrolments e2 join public.classes c2 on c2.id = e2.class_id
        where e2.student_profile_id = m.profile_id and c2.kind = 'register') as grade
from public.school_memberships m
join public.schools sc on sc.id = m.school_id and sc.slug = 'styfe'
join public.enrolments e on e.student_profile_id = m.profile_id
join public.class_subjects cs on cs.class_id = e.class_id
join public.subjects s on s.id = cs.subject_id
join public.subject_offerings o on o.subject_id = s.id
where m.role = 'student';

create temp view styfe_learners as
select m.profile_id, m.email, m.date_of_birth, m.phone,
       (select c.grade::int from public.enrolments e join public.classes c on c.id = e.class_id
        where e.student_profile_id = m.profile_id and c.kind = 'register') as grade
from public.school_memberships m
join public.schools sc on sc.id = m.school_id and sc.slug = 'styfe'
where m.role = 'student';

-- ---------------------------------------------------------------------------------
-- The school and its people
-- ---------------------------------------------------------------------------------

select ok((select is_demo from public.schools where slug = 'styfe'), 'Styfe is marked as a demo school');

select is((select count(*)::int from styfe_learners), 150, '150 learners');

select results_eq(
  $$ select c.name, count(e.*)::int from public.classes c
     join public.schools s on s.id = c.school_id and s.slug = 'styfe'
     left join public.enrolments e on e.class_id = c.id
     where c.kind = 'register' group by c.name order by c.name $$,
  $$ values ('10A', 25), ('10B', 25), ('11A', 25), ('11B', 25), ('12A', 25), ('12B', 25) $$,
  'Classes A and B in Grades 10-12, exactly 25 learners each'
);

select is_empty(
  $$ select l.profile_id from styfe_learners l
     where (select count(*) from public.enrolments e join public.classes c on c.id = e.class_id
            where e.student_profile_id = l.profile_id and c.kind = 'register') <> 1 $$,
  'Every learner is in exactly one register class'
);

select results_eq(
  $$ select l.grade, count(*) filter (where exists (
         select 1 from styfe_takes t where t.profile_id = l.profile_id and t.subject = 'Mathematics'))::int
     from styfe_learners l group by l.grade order by l.grade $$,
  $$ values (10, 35), (11, 33), (12, 31) $$,
  'Mathematics vs Mathematical Literacy: 70/30, 66/34, 62/38'
);

select is(
  (select count(distinct m.profile_id)::int from public.school_memberships m
   join public.schools s on s.id = m.school_id and s.slug = 'styfe'
   where m.role in ('teacher', 'school_admin')),
  23,
  '23 staff: 22 teach, the principal and deputy are school admins (the deputy also teaches)'
);

select results_eq(
  $$ select m.job_title from public.school_memberships m
     join public.schools s on s.id = m.school_id and s.slug = 'styfe'
     where m.role = 'school_admin' order by 1 $$,
  $$ values ('Deputy Principal'), ('Principal') $$,
  'The principal and deputy run the school'
);

-- ---------------------------------------------------------------------------------
-- Subject packages (brief section 9)
-- ---------------------------------------------------------------------------------

select is_empty(
  $$ select l.profile_id from styfe_learners l
     where (select count(*) from styfe_takes t where t.profile_id = l.profile_id
            and t.subject in ('English Home Language', 'Afrikaans First Additional Language', 'Life Orientation')) <> 3
        or not exists (select 1 from styfe_takes t where t.profile_id = l.profile_id
                       and t.subject in ('Mathematics', 'Mathematical Literacy')) $$,
  'Every learner takes the 4 fundamentals: English HL, Afrikaans FAL, LO, and Maths or Maths Literacy'
);

select is_empty(
  $$ select l.profile_id from styfe_learners l
     where (select count(*) from styfe_takes t where t.profile_id = l.profile_id and t.kind = 'elective') <> 3
        or (select count(distinct t.block) from styfe_takes t where t.profile_id = l.profile_id and t.kind = 'elective') <> 3 $$,
  'Every learner takes 3 electives, from 3 different blocks'
);

select is_empty(
  $$ select t.profile_id, t.subject from styfe_takes t where t.grade not between t.min_grade and t.max_grade $$,
  'Nobody takes a subject outside the grades it is offered in (Further Studies is Grades 11-12 only)'
);

-- Every school rule holds for every learner in the rule's grades.
select is_empty(
  $$ select r.description, l.profile_id
     from public.school_subject_rules r
     join public.schools s on s.id = r.school_id and s.slug = 'styfe'
     join styfe_learners l on l.grade between r.min_grade and r.max_grade
     where (r.rule_type = 'mutually_exclusive' and (
              select count(*) from public.school_subject_rule_members rm
              join styfe_takes t on t.subject_id = rm.subject_id and t.profile_id = l.profile_id
              where rm.rule_id = r.id) > 1)
        or (r.rule_type = 'requires'
            and exists (select 1 from public.school_subject_rule_members rm
                        join styfe_takes t on t.subject_id = rm.subject_id and t.profile_id = l.profile_id
                        where rm.rule_id = r.id and rm.member_role = 'subject')
            and not exists (select 1 from public.school_subject_rule_members rm
                            join styfe_takes t on t.subject_id = rm.subject_id and t.profile_id = l.profile_id
                            where rm.rule_id = r.id and rm.member_role = 'required')) $$,
  'Every school rule holds: Physical Sciences and IT need Maths, Maths Literacy excludes both, Maths or Maths Literacy in Grade 10'
);

select is_empty(
  $$ select l.profile_id from styfe_learners l
     where exists (select 1 from styfe_takes t where t.profile_id = l.profile_id and t.subject = 'Mathematics')
       and exists (select 1 from styfe_takes t where t.profile_id = l.profile_id and t.subject = 'Mathematical Literacy')
       and (l.grade < 11 or exists (select 1 from styfe_takes t where t.profile_id = l.profile_id
                                    and t.subject in ('Physical Sciences', 'Information Technology'))) $$,
  'The Maths + Maths Literacy package is Grades 11-12 only, and never with Physical Sciences or IT'
);

select results_eq(
  $$ select l.grade,
            count(*) filter (where exists (select 1 from styfe_takes t where t.profile_id = l.profile_id
                                           and t.subject = 'French Second Additional Language'))::int,
            count(*) filter (where exists (select 1 from styfe_takes t where t.profile_id = l.profile_id
                                           and t.subject = 'Further Studies Mathematics'))::int,
            count(*) filter (where exists (select 1 from styfe_takes t where t.profile_id = l.profile_id
                                           and t.subject = 'Further Studies English'))::int,
            count(*) filter (where (select count(*) from styfe_takes t where t.profile_id = l.profile_id
                                    and t.subject in ('Mathematics', 'Mathematical Literacy')) = 2)::int
     from styfe_learners l group by l.grade order by l.grade $$,
  $$ values (10, 5, 0, 0, 0), (11, 5, 4, 3, 3), (12, 5, 4, 3, 3) $$,
  'Extras per grade: 5 French; in Grades 11-12, 4 Further Studies Maths, 3 Further Studies English, 3 on the package'
);

select results_eq(
  $$ select p.full_name, l.grade,
            (select string_agg(t.subject, ', ' order by t.subject) from styfe_takes t
             where t.profile_id = l.profile_id
               and t.subject not in ('English Home Language', 'Afrikaans First Additional Language', 'Life Orientation'))
     from private.demo_learner_traits h
     join public.profiles p on p.id = h.profile_id
     join styfe_learners l on l.profile_id = h.profile_id
     where h.hero is not null order by p.full_name $$,
  $$ values
       ('Aaliyah Davids', 11, 'Accounting, Business Studies, Geography, Mathematical Literacy, Mathematics'),
       ('Ethan van der Merwe', 12, 'Business Studies, Design, History, Mathematical Literacy'),
       ('Liam Jacobs', 10, 'Accounting, Business Studies, Economics, Mathematics'),
       ('Sipho Ndlovu', 11, 'Further Studies Mathematics, Information Technology, Life Sciences, Mathematics, Physical Sciences'),
       ('Thando Mokoena', 12, 'Geography, Life Sciences, Mathematics, Physical Sciences') $$,
  'The five hero learners have the subjects the walkthrough needs'
);

select results_eq(
  $$ select c.name from public.classes c join public.schools s on s.id = c.school_id and s.slug = 'styfe'
     join public.enrolments e on e.class_id = c.id
     join private.demo_learner_traits h on h.profile_id = e.student_profile_id
     join public.profiles p on p.id = h.profile_id
     where p.full_name in ('Thando Mokoena', 'Liam Jacobs') and c.kind = 'register' order by p.full_name $$,
  $$ values ('10B'), ('12A') $$,
  'Heroes are in the brief''s classes (Liam 10B, Thando 12A)'
);

select is_empty(
  $$ select g.name from public.classes g join public.schools s on s.id = g.school_id and s.slug = 'styfe'
     join public.enrolments e on e.class_id = g.id
     where g.kind = 'subject_group' group by g.name having count(*) > 28 $$,
  'No subject group has more than 28 learners'
);

-- ---------------------------------------------------------------------------------
-- Teachers, parents, contact details
-- ---------------------------------------------------------------------------------

select is_empty(
  $$ select cs.id from public.class_subjects cs join public.schools s on s.id = cs.school_id and s.slug = 'styfe'
     where not exists (select 1 from public.teaching_allocations ta where ta.class_subject_id = cs.id) $$,
  'Every class has a teacher for every subject'
);

select results_eq(
  $$ select distinct sub.name from public.teaching_allocations ta
     join public.school_memberships m on m.profile_id = ta.teacher_profile_id and m.email = 'dan@styfe.co.za'
     join public.class_subjects cs on cs.id = ta.class_subject_id
     join public.subjects sub on sub.id = cs.subject_id order by 1 $$,
  $$ values ('Further Studies Mathematics'), ('Mathematics') $$,
  'The maths teacher login (given in mixed case, stored lowercase) teaches Maths and Further Studies Maths'
);

select is_empty(
  $$ select l.profile_id from styfe_learners l
     where (select count(*) from public.guardianships g where g.student_profile_id = l.profile_id) not between 1 and 2
        or (select count(*) from public.guardianships g where g.student_profile_id = l.profile_id and g.is_primary) <> 1 $$,
  'Every learner has one or two parents, exactly one of them primary'
);

select ok(
  (select count(*) from styfe_learners l
   where (select count(*) from public.guardianships g where g.student_profile_id = l.profile_id) = 2)
  between 90 and 120,
  'About 70% of learners have two parents'
);

select results_eq(
  $$ select p.full_name, g.relationship::text, g.status::text from public.guardianships g
     join public.school_memberships m on m.profile_id = g.parent_profile_id and m.role = 'parent'
       and m.email = 'login@example.org'
     join public.profiles p on p.id = g.student_profile_id $$,
  $$ values ('Thando Mokoena', 'guardian', 'invited') $$,
  'The parent login is Thando''s guardian, invited until they consent'
);

select is_empty(
  $$ select m.email from public.school_memberships m join public.schools s on s.id = m.school_id and s.slug = 'styfe'
     where (m.role = 'parent' and m.email not like '%@example.com' and m.email <> 'login@example.org')
        or (m.role <> 'parent' and m.email not like '%@styfe.co.za') $$,
  'Staff and learners have styfe.co.za emails; parents have reserved example.com ones (except the parent login)'
);

select is_empty(
  $$ select m.email from public.school_memberships m join public.schools s on s.id = m.school_id and s.slug = 'styfe'
     group by m.email having count(distinct m.profile_id) > 1 $$,
  'No two people share an email (sign-in would not know who is who)'
);

select is_empty(
  $$ select m.phone from public.school_memberships m join public.schools s on s.id = m.school_id and s.slug = 'styfe'
     where m.phone is null or m.phone not like '+27 00 %' $$,
  'Every phone number is obviously fake (+27 00 ...)'
);

select is_empty(
  $$ select l.profile_id from styfe_learners l where extract(year from l.date_of_birth) <> 2020 - l.grade $$,
  'Dates of birth match the grade (Grade 12 born 2008, Grade 11 2009, Grade 10 2010)'
);

-- ---------------------------------------------------------------------------------
-- Reloading, removing, and who can do it
-- ---------------------------------------------------------------------------------

create temp table first_load as
select p.full_name, m.email from public.school_memberships m join public.profiles p on p.id = m.profile_id
join public.schools s on s.id = m.school_id and s.slug = 'styfe';

select private.demo_load_styfe('{"maths_teacher": "dan@styfe.co.za", "thando_parent": "login@example.org"}');

select set_eq(
  $$ select p.full_name, m.email from public.school_memberships m join public.profiles p on p.id = m.profile_id
     join public.schools s on s.id = m.school_id and s.slug = 'styfe' $$,
  $$ select * from first_load $$,
  'Reloading replaces Styfe with exactly the same people'
);

select private.demo_remove_school('styfe');

select ok(
  not exists (select 1 from public.schools where slug = 'styfe')
  and not exists (select 1 from public.school_groups where slug = 'styfe')
  and not exists (select 1 from public.school_memberships m where m.email like '%@styfe.co.za')
  and not exists (select 1 from public.profiles p where p.full_name = 'Thando Mokoena')
  and not exists (select 1 from private.demo_learner_traits),
  'Removing Styfe leaves nothing behind: school, group, people, traits'
);

select throws_ok(
  $$ select private.demo_remove_school((select slug from public.schools where not is_demo limit 1)) $$,
  '42501', null,
  'A real school can never be removed by the demo tools'
);

select ok(
  not has_function_privilege('authenticated', 'private.demo_load_styfe(jsonb)', 'EXECUTE')
  and not has_function_privilege('authenticated', 'private.demo_remove_school(text)', 'EXECUTE')
  and not has_function_privilege('anon', 'private.demo_load_styfe(jsonb)', 'EXECUTE'),
  'Nobody signed in can run the demo loader or remover'
);

-- Another school's admin sees none of Styfe's subject set-up.
select private.demo_load_styfe();
select set_config('request.jwt.claims', '{"sub":"30000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
set local role authenticated;
select results_eq(
  $$ select (select count(*)::int from public.subject_offerings),
            (select count(*)::int from public.school_subject_rules),
            (select count(*)::int from public.school_subject_rule_members) $$,
  $$ values (0, 0, 0) $$,
  'Another school''s admin sees none of Styfe''s offerings or rules'
);
reset role;

select * from finish();
rollback;
