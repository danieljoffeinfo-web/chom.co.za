-- The IEB subject catalogue: richer subject details, grade-aware aliases, subject
-- combination rules, and the 42 IEB subjects.
--
-- Source: "Available IEB Subjects - Chom Learn" spreadsheet (2 November 2026), which
-- cites the IEB NSC requirements page:
--   ieb.co.za/assessment/high-schools/national-senior-certificate/nsc-requirements
-- Grades 10-12 subjects are from the IEB's approved NSC subject tables. Grades 8-9-only
-- subjects follow CAPS Senior Phase and are school-assessed.
--
-- Everything here is curriculum data, not code: CAPS and Cambridge are added later the
-- same way, with their own rows.

create extension if not exists btree_gist with schema extensions;

-- ---------------------------------------------------------------------------------
-- 1. More detail on each catalogue subject
-- ---------------------------------------------------------------------------------

create type public.language_level as enum ('home', 'first_additional', 'second_additional');

alter table public.curriculum_subjects
  add column category text,
  add column language_level public.language_level,
  -- Has an external final exam (for IEB: an IEB Grade 12 exam). False for subjects the
  -- school assesses itself, such as Life Orientation and Grades 8-9-only subjects.
  add column externally_examined boolean not null default true,
  -- Every learner takes it (IEB: Life Orientation).
  add column is_compulsory boolean not null default false,
  -- Counts toward the curriculum's certificate (IEB: one of the 7 NSC subjects). False
  -- for extras such as Advanced Programme subjects, and for Grades 8-9-only subjects.
  add column counts_toward_certificate boolean not null default true,
  -- Display order within the curriculum.
  add column sort_order smallint,
  add constraint curriculum_subjects_id_curriculum_key unique (id, curriculum_id);

comment on column public.curriculum_subjects.category is
  'Grouping for setup screens, e.g. Languages, Mathematics, Sciences.';

-- ---------------------------------------------------------------------------------
-- 2. Aliases: other names schools use for a subject, valid for a range of grades
-- ---------------------------------------------------------------------------------

-- Used to match names from spreadsheets and Ednana ("Maths Lit", "CAT") to the official
-- subject. Grade-aware: "Science" means Natural Sciences in Grades 8-9 and Physical
-- Sciences in Grades 10-12. Within one curriculum, the same alias can never apply to
-- two subjects in the same grade, so a match is never ambiguous.
create table public.curriculum_subject_aliases (
  id uuid primary key default gen_random_uuid(),
  curriculum_id uuid not null,
  curriculum_subject_id uuid not null,
  alias text not null check (length(trim(alias)) > 0),
  min_grade smallint not null check (min_grade between 0 and 12),
  max_grade smallint not null check (max_grade between 0 and 12),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (min_grade <= max_grade),
  foreign key (curriculum_subject_id, curriculum_id)
    references public.curriculum_subjects (id, curriculum_id) on delete cascade,
  constraint curriculum_subject_aliases_no_overlap exclude using gist (
    curriculum_id with =,
    lower(alias) with =,
    int4range(min_grade, max_grade, '[]') with &&
  )
);

comment on table public.curriculum_subject_aliases is
  'Other names for a catalogue subject, valid for a grade range. Never ambiguous within a curriculum and grade.';

create index curriculum_subject_aliases_subject_idx
  on public.curriculum_subject_aliases (curriculum_subject_id, curriculum_id);

create trigger curriculum_subject_aliases_set_updated_at before update on public.curriculum_subject_aliases
  for each row execute function private.set_updated_at();

-- ---------------------------------------------------------------------------------
-- 3. Subject combination rules (stored now; enforced when subject choice is built)
-- ---------------------------------------------------------------------------------

create type public.subject_rule_type as enum (
  -- A learner may take at most one of the member subjects.
  'mutually_exclusive',
  -- A learner taking the 'subject' member must also take the 'required' member.
  'requires',
  -- A learner may take at most max_count of the member subjects.
  'max_from_group'
);

create table public.curriculum_subject_rules (
  id uuid primary key default gen_random_uuid(),
  curriculum_id uuid not null references public.curricula (id) on delete restrict,
  rule_type public.subject_rule_type not null,
  max_count smallint check (max_count is null or max_count > 0),
  min_grade smallint not null check (min_grade between 0 and 12),
  max_grade smallint not null check (max_grade between 0 and 12),
  description text not null check (length(trim(description)) > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (min_grade <= max_grade),
  check ((rule_type = 'max_from_group') = (max_count is not null)),
  unique (id, curriculum_id)
);

comment on table public.curriculum_subject_rules is
  'Subject combination rules per curriculum, e.g. Mathematics or Mathematical Literacy, never both. Not yet enforced.';

create table public.curriculum_subject_rule_members (
  rule_id uuid not null,
  curriculum_id uuid not null,
  curriculum_subject_id uuid not null,
  -- 'member' for mutually_exclusive and max_from_group; 'subject' or 'required' for requires.
  member_role text not null default 'member' check (member_role in ('member', 'subject', 'required')),
  primary key (rule_id, curriculum_subject_id),
  foreign key (rule_id, curriculum_id)
    references public.curriculum_subject_rules (id, curriculum_id) on delete cascade,
  foreign key (curriculum_subject_id, curriculum_id)
    references public.curriculum_subjects (id, curriculum_id) on delete restrict
);

create index curriculum_subject_rule_members_subject_idx
  on public.curriculum_subject_rule_members (curriculum_subject_id, curriculum_id);

create trigger curriculum_subject_rules_set_updated_at before update on public.curriculum_subject_rules
  for each row execute function private.set_updated_at();

-- Reference data: readable by every signed-in user, changed only by migrations.
select private.expose_table('public.curriculum_subject_aliases', 'select');
select private.expose_table('public.curriculum_subject_rules', 'select');
select private.expose_table('public.curriculum_subject_rule_members', 'select');

create policy "Signed-in users can read subject aliases"
  on public.curriculum_subject_aliases for select to authenticated
  using (true);

create policy "Signed-in users can read subject rules"
  on public.curriculum_subject_rules for select to authenticated
  using (true);

create policy "Signed-in users can read subject rule members"
  on public.curriculum_subject_rule_members for select to authenticated
  using (true);

-- ---------------------------------------------------------------------------------
-- 4. Matching a name to a catalogue subject
-- ---------------------------------------------------------------------------------

-- Returns the catalogue subject a name refers to in a given grade, or null if there is
-- no match. Official names win over aliases. Case and extra whitespace (spaces, tabs,
-- line breaks) are ignored.
--   select public.resolve_curriculum_subject('IEB', 'Maths Lit', 11);
create function public.resolve_curriculum_subject(
  p_curriculum_code text,
  p_name text,
  p_grade integer
)
returns uuid
language sql
stable
security invoker
set search_path = ''
as $$
  with wanted as (
    -- Collapse every run of whitespace (tabs, line breaks) to one space, then trim.
    select lower(trim(regexp_replace(p_name, '\s+', ' ', 'g'))) as name
  ),
  curriculum as (
    select id from public.curricula where code = upper(trim(p_curriculum_code))
  )
  select coalesce(
    (
      select s.id
      from public.curriculum_subjects s, wanted, curriculum
      where s.curriculum_id = curriculum.id
        and lower(s.name) = wanted.name
        and p_grade between s.min_grade and s.max_grade
      limit 1
    ),
    (
      select a.curriculum_subject_id
      from public.curriculum_subject_aliases a, wanted, curriculum
      where a.curriculum_id = curriculum.id
        and lower(a.alias) = wanted.name
        and p_grade between a.min_grade and a.max_grade
      limit 1
    )
  )
$$;

revoke execute on function public.resolve_curriculum_subject(text, text, integer) from public, anon;
grant execute on function public.resolve_curriculum_subject(text, text, integer) to authenticated, service_role;

-- ---------------------------------------------------------------------------------
-- 5. The IEB subjects
-- ---------------------------------------------------------------------------------

with ieb as (select id from public.curricula where code = 'IEB')
insert into public.curriculum_subjects (
  curriculum_id, sort_order, name, min_grade, max_grade, category, language_level,
  externally_examined, is_compulsory, counts_toward_certificate
)
select ieb.id, s.sort_order, s.name, s.min_grade, s.max_grade, s.category,
       s.language_level::public.language_level,
       s.externally_examined, s.is_compulsory, s.counts_toward_certificate
from ieb, (values
  -- sort, name,                                     from, to, category,           language level,      external, compulsory, counts
  ( 1, 'English Home Language',                     8, 12, 'Languages',        'home',              true,  false, true),
  ( 2, 'Afrikaans Home Language',                   8, 12, 'Languages',        'home',              true,  false, true),
  ( 3, 'Afrikaans First Additional Language',       8, 12, 'Languages',        'first_additional',  true,  false, true),
  ( 4, 'isiZulu Home Language',                     8, 12, 'Languages',        'home',              true,  false, true),
  ( 5, 'isiZulu First Additional Language',         8, 12, 'Languages',        'first_additional',  true,  false, true),
  ( 6, 'isiXhosa First Additional Language',        8, 12, 'Languages',        'first_additional',  true,  false, true),
  ( 7, 'Sesotho First Additional Language',         8, 12, 'Languages',        'first_additional',  true,  false, true),
  ( 8, 'Setswana First Additional Language',        8, 12, 'Languages',        'first_additional',  true,  false, true),
  ( 9, 'French Second Additional Language',         8, 12, 'Languages',        'second_additional', true,  false, true),
  (10, 'German Second Additional Language',         8, 12, 'Languages',        'second_additional', true,  false, true),
  (11, 'Portuguese Second Additional Language',     8, 12, 'Languages',        'second_additional', true,  false, true),
  (12, 'Mandarin Second Additional Language',       8, 12, 'Languages',        'second_additional', true,  false, true),
  (13, 'Mathematics',                               8, 12, 'Mathematics',      null,                true,  false, true),
  (14, 'Mathematical Literacy',                    10, 12, 'Mathematics',      null,                true,  false, true),
  (15, 'Advanced Programme Mathematics',           10, 12, 'Mathematics',      null,                true,  false, false),
  (16, 'Advanced Programme English',               10, 12, 'Languages',        null,                true,  false, false),
  (17, 'Life Orientation',                          8, 12, 'Life Orientation', null,                false, true,  true),
  (18, 'Natural Sciences',                          8,  9, 'Sciences',         null,                false, false, false),
  (19, 'Physical Sciences',                        10, 12, 'Sciences',         null,                true,  false, true),
  (20, 'Life Sciences',                            10, 12, 'Sciences',         null,                true,  false, true),
  (21, 'Agricultural Science',                     10, 12, 'Sciences',         null,                true,  false, true),
  (22, 'Marine Sciences',                          10, 12, 'Sciences',         null,                true,  false, true),
  (23, 'Geography',                                 8, 12, 'Humanities',       null,                true,  false, true),
  (24, 'History',                                   8, 12, 'Humanities',       null,                true,  false, true),
  (25, 'Sports and Exercise Science',              10, 12, 'Sciences',         null,                true,  false, true),
  (26, 'Economic and Management Sciences',          8,  9, 'Commerce',         null,                false, false, false),
  (27, 'Accounting',                               10, 12, 'Commerce',         null,                true,  false, true),
  (28, 'Business Studies',                         10, 12, 'Commerce',         null,                true,  false, true),
  (29, 'Economics',                                10, 12, 'Commerce',         null,                true,  false, true),
  (30, 'Technology',                                8,  9, 'Technology',       null,                false, false, false),
  (31, 'Information Technology',                   10, 12, 'Technology',       null,                true,  false, true),
  (32, 'Computer Applications Technology',         10, 12, 'Technology',       null,                true,  false, true),
  (33, 'Engineering Graphics and Design',          10, 12, 'Technology',       null,                true,  false, true),
  (34, 'Creative Arts',                             8,  9, 'Arts',             null,                false, false, false),
  (35, 'Visual Arts',                              10, 12, 'Arts',             null,                true,  false, true),
  (36, 'Dramatic Arts',                            10, 12, 'Arts',             null,                true,  false, true),
  (37, 'Music',                                    10, 12, 'Arts',             null,                true,  false, true),
  (38, 'Dance Studies',                            10, 12, 'Arts',             null,                true,  false, true),
  (39, 'Design',                                   10, 12, 'Arts',             null,                true,  false, true),
  (40, 'Consumer Studies',                         10, 12, 'Services',         null,                true,  false, true),
  (41, 'Hospitality Studies',                      10, 12, 'Services',         null,                true,  false, true),
  (42, 'Tourism',                                  10, 12, 'Services',         null,                true,  false, true)
) as s (sort_order, name, min_grade, max_grade, category, language_level,
        externally_examined, is_compulsory, counts_toward_certificate);

-- Aliases from the spreadsheet, valid for each subject's own grades, plus "Science" for
-- Natural Sciences in Grades 8-9 (the spreadsheet lists "Science" for Physical
-- Sciences, which only covers Grades 10-12).
with ieb as (select id from public.curricula where code = 'IEB')
insert into public.curriculum_subject_aliases (curriculum_id, curriculum_subject_id, alias, min_grade, max_grade)
select ieb.id, s.id, a.alias, coalesce(a.min_grade, s.min_grade), coalesce(a.max_grade, s.max_grade)
from ieb
join (values
  ('Mathematical Literacy',            'Maths Lit',                    null::smallint, null::smallint),
  ('Advanced Programme Mathematics',   'AP Maths',                     null, null),
  ('Advanced Programme Mathematics',   'Further Studies Mathematics',  null, null),
  ('Advanced Programme English',       'AP English',                   null, null),
  ('Advanced Programme English',       'Further Studies English',      null, null),
  ('Life Orientation',                 'LO',                           null, null),
  ('Physical Sciences',                'Science',                      null, null),
  ('Natural Sciences',                 'Science',                      null, null),
  ('Life Sciences',                    'Biology',                      null, null),
  ('Economic and Management Sciences', 'EMS',                          null, null),
  ('Information Technology',           'IT',                           null, null),
  ('Computer Applications Technology', 'CAT',                          null, null),
  ('Engineering Graphics and Design',  'EGD',                          null, null),
  ('Dramatic Arts',                    'Drama',                        null, null)
) as a (subject_name, alias, min_grade, max_grade) on true
join public.curriculum_subjects s on s.curriculum_id = ieb.id and s.name = a.subject_name;

-- Combination rules from the spreadsheet's notes. Life Orientation being compulsory is
-- the is_compulsory column, not a rule.
with ieb as (select id from public.curricula where code = 'IEB'),
rules as (
  insert into public.curriculum_subject_rules (curriculum_id, rule_type, max_count, min_grade, max_grade, description)
  select ieb.id, r.rule_type::public.subject_rule_type, r.max_count, 10, 12, r.description
  from ieb, (values
    ('mutually_exclusive', null::smallint, 'Learners take either Mathematics or Mathematical Literacy, never both.'),
    ('requires',           null,           'Physical Sciences must be taken with Mathematics.'),
    ('mutually_exclusive', null,           'Consumer Studies may not be taken with Hospitality Studies.'),
    ('max_from_group',     1,              'Marine Sciences and Sports and Exercise Science are Other Approved Subjects: at most one among a learner''s three electives.')
  ) as r (rule_type, max_count, description)
  returning id, curriculum_id, description
)
insert into public.curriculum_subject_rule_members (rule_id, curriculum_id, curriculum_subject_id, member_role)
select rules.id, rules.curriculum_id, s.id, m.member_role
from rules
join (values
  ('Learners take either Mathematics or Mathematical Literacy, never both.', 'Mathematics',                 'member'),
  ('Learners take either Mathematics or Mathematical Literacy, never both.', 'Mathematical Literacy',       'member'),
  ('Physical Sciences must be taken with Mathematics.',                      'Physical Sciences',           'subject'),
  ('Physical Sciences must be taken with Mathematics.',                      'Mathematics',                 'required'),
  ('Consumer Studies may not be taken with Hospitality Studies.',            'Consumer Studies',            'member'),
  ('Consumer Studies may not be taken with Hospitality Studies.',            'Hospitality Studies',         'member'),
  ('Marine Sciences and Sports and Exercise Science are Other Approved Subjects: at most one among a learner''s three electives.', 'Marine Sciences',             'member'),
  ('Marine Sciences and Sports and Exercise Science are Other Approved Subjects: at most one among a learner''s three electives.', 'Sports and Exercise Science', 'member')
) as m (description, subject_name, member_role) on m.description = rules.description
join public.curriculum_subjects s on s.curriculum_id = rules.curriculum_id and s.name = m.subject_name;
