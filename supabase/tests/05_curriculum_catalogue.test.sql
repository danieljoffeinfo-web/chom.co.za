-- The IEB subject catalogue: subjects, details, grade-aware aliases and rules.
-- Expected values come from the "Available IEB Subjects - Chom Learn" spreadsheet.

begin;
create extension if not exists pgtap with schema extensions;

select plan(30);

-- ---------------------------------------------------------------------------------
-- Subjects and their details
-- ---------------------------------------------------------------------------------

select is(
  (select count(*)::int from public.curriculum_subjects s join public.curricula c on c.id = s.curriculum_id where c.code = 'IEB'),
  42,
  'All 42 IEB subjects are in the catalogue'
);
select is(
  (select array_agg(sort_order order by sort_order) from public.curriculum_subjects),
  (select array_agg(n::smallint) from generate_series(1, 42) n),
  'Subjects keep the spreadsheet''s order, 1 to 42, with no gaps'
);
select results_eq(
  $$ select min_grade::int, max_grade::int from public.curriculum_subjects where name = 'Mathematical Literacy' $$,
  $$ values (10, 12) $$,
  'Mathematical Literacy runs Grades 10-12'
);
select results_eq(
  $$ select min_grade::int, max_grade::int from public.curriculum_subjects where name = 'Natural Sciences' $$,
  $$ values (8, 9) $$,
  'Natural Sciences runs Grades 8-9'
);
select is(
  (select count(*)::int from public.curriculum_subjects where language_level is not null),
  12,
  'Twelve subjects are language levels (Home, First Additional, Second Additional)'
);
select is(
  (select language_level::text from public.curriculum_subjects where name = 'isiXhosa First Additional Language'),
  'first_additional',
  'Language level is recorded separately from the name'
);
select results_eq(
  $$ select is_compulsory, externally_examined, counts_toward_certificate
     from public.curriculum_subjects where name = 'Life Orientation' $$,
  $$ values (true, false, true) $$,
  'Life Orientation: compulsory, school-assessed, counts toward the NSC'
);
select results_eq(
  $$ select name from public.curriculum_subjects where is_compulsory order by name $$,
  $$ values ('Life Orientation') $$,
  'Life Orientation is the only compulsory subject'
);
select results_eq(
  $$ select name from public.curriculum_subjects where not counts_toward_certificate and min_grade >= 10 order by name $$,
  $$ values ('Advanced Programme English'), ('Advanced Programme Mathematics') $$,
  'Advanced Programme subjects are extras that do not count toward the 7 NSC subjects'
);
select results_eq(
  $$ select name from public.curriculum_subjects where not externally_examined order by name $$,
  $$ values ('Creative Arts'), ('Economic and Management Sciences'), ('Life Orientation'),
            ('Natural Sciences'), ('Technology') $$,
  'Only Life Orientation and the Grades 8-9-only subjects are school-assessed'
);

-- ---------------------------------------------------------------------------------
-- Matching names to subjects, with grade-aware aliases
-- ---------------------------------------------------------------------------------

select is(
  public.resolve_curriculum_subject('IEB', 'Maths Lit', 11),
  (select id from public.curriculum_subjects where name = 'Mathematical Literacy'),
  '"Maths Lit" in Grade 11 is Mathematical Literacy'
);
select is(
  public.resolve_curriculum_subject('IEB', 'Science', 9),
  (select id from public.curriculum_subjects where name = 'Natural Sciences'),
  '"Science" in Grade 9 is Natural Sciences'
);
select is(
  public.resolve_curriculum_subject('IEB', 'Science', 11),
  (select id from public.curriculum_subjects where name = 'Physical Sciences'),
  '"Science" in Grade 11 is Physical Sciences'
);
select is(
  public.resolve_curriculum_subject('ieb', '  further   studies MATHEMATICS ', 12),
  (select id from public.curriculum_subjects where name = 'Advanced Programme Mathematics'),
  'Matching ignores case and extra spaces'
);
select is(
  public.resolve_curriculum_subject('IEB', E'\tMaths Lit\r\n', 11),
  (select id from public.curriculum_subjects where name = 'Mathematical Literacy'),
  'Matching ignores tabs and line breaks around a name (common in spreadsheet imports)'
);
select is(
  public.resolve_curriculum_subject('IEB', 'Life Orientation', 8),
  (select id from public.curriculum_subjects where name = 'Life Orientation'),
  'Official names match directly'
);
select is(
  public.resolve_curriculum_subject('IEB', 'Natural Sciences', 11),
  null,
  'A subject does not match outside its grades (Natural Sciences in Grade 11)'
);
select is(
  public.resolve_curriculum_subject('IEB', 'Underwater Basket Weaving', 10),
  null,
  'Unknown names do not match anything'
);
select is_empty(
  $$ select a.alias from public.curriculum_subject_aliases a
     where public.resolve_curriculum_subject('IEB', a.alias, a.min_grade) is distinct from a.curriculum_subject_id
        or public.resolve_curriculum_subject('IEB', a.alias, a.max_grade) is distinct from a.curriculum_subject_id $$,
  'Every alias resolves to its own subject at both ends of its grade range'
);
select is_empty(
  $$ select a.alias from public.curriculum_subject_aliases a
     join public.curriculum_subjects s on s.id = a.curriculum_subject_id
     where a.min_grade < s.min_grade or a.max_grade > s.max_grade $$,
  'No alias reaches outside its subject''s grades'
);
select throws_ok(
  $$ insert into public.curriculum_subject_aliases (curriculum_id, curriculum_subject_id, alias, min_grade, max_grade)
     select s.curriculum_id, s.id, 'SCIENCE', 10, 12 from public.curriculum_subjects s where s.name = 'Life Sciences' $$,
  '23P01', null,
  'An alias can never point to two subjects in the same grade'
);

-- ---------------------------------------------------------------------------------
-- Combination rules (stored, not yet enforced)
-- ---------------------------------------------------------------------------------

select is((select count(*)::int from public.curriculum_subject_rules), 4, 'Four combination rules are stored');
select results_eq(
  $$ select s.name from public.curriculum_subject_rule_members m
     join public.curriculum_subject_rules r on r.id = m.rule_id
     join public.curriculum_subjects s on s.id = m.curriculum_subject_id
     where r.rule_type = 'mutually_exclusive' and r.description like '%Mathematical Literacy%'
     order by s.name $$,
  $$ values ('Mathematical Literacy'), ('Mathematics') $$,
  'Mathematics and Mathematical Literacy are mutually exclusive'
);
select results_eq(
  $$ select s.name, m.member_role from public.curriculum_subject_rule_members m
     join public.curriculum_subject_rules r on r.id = m.rule_id
     join public.curriculum_subjects s on s.id = m.curriculum_subject_id
     where r.rule_type = 'requires' order by m.member_role desc $$,
  $$ values ('Physical Sciences', 'subject'), ('Mathematics', 'required') $$,
  'Physical Sciences requires Mathematics'
);
select results_eq(
  $$ select r.max_count::int, count(*)::int from public.curriculum_subject_rules r
     join public.curriculum_subject_rule_members m on m.rule_id = r.id
     where r.rule_type = 'max_from_group' group by r.max_count $$,
  $$ values (1, 2) $$,
  'At most one of Marine Sciences and Sports and Exercise Science'
);

-- ---------------------------------------------------------------------------------
-- Who can read and change the catalogue
-- ---------------------------------------------------------------------------------

select set_config('request.jwt.claims', '{"sub":"30000000-0000-4000-8000-000000000004","role":"authenticated"}', true);
set local role authenticated;

select is(
  (select count(*)::int from public.curriculum_subject_aliases),
  14,
  'Signed-in users can read all 14 aliases'
);
select isnt(
  public.resolve_curriculum_subject('IEB', 'Maths Lit', 11),
  null,
  'Signed-in users can use the subject matcher'
);
select is(
  public.resolve_curriculum_subject('IEB', 'Maths Lit', 11),
  (select id from public.curriculum_subjects where name = 'Mathematical Literacy'),
  'Signed-in users get the right subject from the matcher'
);
select throws_ok(
  $$ insert into public.curriculum_subject_aliases (curriculum_id, curriculum_subject_id, alias, min_grade, max_grade)
     select s.curriculum_id, s.id, 'Hack', 10, 12 from public.curriculum_subjects s where s.name = 'Music' $$,
  '42501', null,
  'Signed-in users cannot change the catalogue'
);

reset role;

select set_config('request.jwt.claims', '{"role":"anon"}', true);
set local role anon;
select throws_ok(
  $$ select public.resolve_curriculum_subject('IEB', 'Maths Lit', 11) $$,
  '42501', null,
  'Signed-out visitors cannot use the subject matcher'
);
reset role;

select * from finish();
rollback;
