-- Demo schools, slice 1: the roster.
--
-- What this adds:
--   1. schools.is_demo: demo schools can be wiped and reloaded; real schools never.
--   2. Personal details on a membership (date of birth, phone, job title). They sit on
--      the membership, not the profile, so only the person and their school admins see
--      them (memberships are already limited to exactly that).
--   3. Per-school subject set-up: which subjects a school offers each year, as
--      fundamentals, electives (in timetable blocks, one subject per block) or extras,
--      and the school's own combination rules (IT needs Mathematics, and so on).
--   4. The demo loader for Styfe School (3-term, Grades 10-12) from the demo data brief,
--      and a function that removes a demo school completely.
--
-- Calendars, curriculum units, assessments and marks come in later slices.

-- ---------------------------------------------------------------------------------
-- 1. Demo schools
-- ---------------------------------------------------------------------------------

alter table public.schools add column is_demo boolean not null default false;

comment on column public.schools.is_demo is
  'A demo school: made-up people, safe to wipe and reload with private.demo_remove_school(). Never set on a real school.';

-- ---------------------------------------------------------------------------------
-- 2. Personal details on a membership
-- ---------------------------------------------------------------------------------

alter table public.school_memberships
  add column date_of_birth date
    check (date_of_birth is null or date_of_birth between '1900-01-01' and '2100-12-31'),
  add column phone text
    check (phone is null or phone ~ '^\+[0-9][0-9 ]{7,19}$'),
  add column job_title text
    check (job_title is null or length(trim(job_title)) > 0);

comment on column public.school_memberships.date_of_birth is
  'As the school records it. Visible to the person and their school admins only.';
comment on column public.school_memberships.phone is
  'International format, e.g. +27 82 123 4567. Visible to the person and their school admins only.';
comment on column public.school_memberships.job_title is
  'For staff: Principal, Deputy Principal, Head of Mathematics. Display only; access comes from the role.';

grant update (date_of_birth, phone, job_title) on public.school_memberships to authenticated;

-- ---------------------------------------------------------------------------------
-- 3. What a school offers, and its own combination rules
-- ---------------------------------------------------------------------------------

create type public.offering_kind as enum (
  -- Every learner takes it (or one of an either/or pair, such as Mathematics or
  -- Mathematical Literacy, enforced by the school's rules).
  'fundamental',
  -- Chosen: one subject per timetable block.
  'elective',
  -- An optional additional subject (Further Studies, a second additional language).
  'extra'
);

create table public.subject_offerings (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null,
  academic_year_id uuid not null,
  subject_id uuid not null,
  kind public.offering_kind not null,
  -- The timetable line an elective sits in: A, B, C. Electives only.
  block text check (block is null or block ~ '^[A-Z0-9]{1,3}$'),
  min_grade smallint not null check (min_grade between 0 and 12),
  max_grade smallint not null check (max_grade between 0 and 12),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (min_grade <= max_grade),
  check ((kind = 'elective') = (block is not null)),
  unique (academic_year_id, subject_id),
  foreign key (academic_year_id, school_id)
    references public.academic_years (id, school_id) on delete restrict,
  foreign key (subject_id, school_id)
    references public.subjects (id, school_id) on delete restrict
);

comment on table public.subject_offerings is
  'Which subjects a school offers in a year, for which grades, as fundamental, elective (in a timetable block) or extra.';

create index subject_offerings_school_id_idx on public.subject_offerings (school_id);
create index subject_offerings_academic_year_id_school_id_idx
  on public.subject_offerings (academic_year_id, school_id);
create index subject_offerings_subject_id_school_id_idx
  on public.subject_offerings (subject_id, school_id);

create table public.school_subject_rules (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete restrict,
  rule_type public.subject_rule_type not null,
  max_count smallint check (max_count is null or max_count > 0),
  min_grade smallint not null check (min_grade between 0 and 12),
  max_grade smallint not null check (max_grade between 0 and 12),
  description text not null check (length(trim(description)) > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (min_grade <= max_grade),
  check ((rule_type = 'max_from_group') = (max_count is not null)),
  unique (id, school_id)
);

comment on table public.school_subject_rules is
  'A school''s own subject combination rules, on top of the curriculum''s. Same rule types as curriculum_subject_rules.';

create index school_subject_rules_school_id_idx on public.school_subject_rules (school_id);

create table public.school_subject_rule_members (
  rule_id uuid not null,
  school_id uuid not null,
  subject_id uuid not null,
  -- 'member' for mutually_exclusive and max_from_group; 'subject' or 'required' for requires.
  member_role text not null default 'member' check (member_role in ('member', 'subject', 'required')),
  primary key (rule_id, subject_id),
  foreign key (rule_id, school_id)
    references public.school_subject_rules (id, school_id) on delete cascade,
  foreign key (subject_id, school_id)
    references public.subjects (id, school_id) on delete restrict
);

create index school_subject_rule_members_rule_id_school_id_idx
  on public.school_subject_rule_members (rule_id, school_id);
create index school_subject_rule_members_subject_id_school_id_idx
  on public.school_subject_rule_members (subject_id, school_id);

create trigger subject_offerings_set_updated_at before update on public.subject_offerings
  for each row execute function private.set_updated_at();
create trigger school_subject_rules_set_updated_at before update on public.school_subject_rules
  for each row execute function private.set_updated_at();

create trigger subject_offerings_audit after insert or update or delete on public.subject_offerings
  for each row execute function private.audit_row_change();
create trigger school_subject_rules_audit after insert or update or delete on public.school_subject_rules
  for each row execute function private.audit_row_change();

-- Everyone at the school can see what it offers (learners will choose from it); school
-- admins change it.
select private.expose_table('public.subject_offerings', 'select, insert, update, delete');
select private.expose_table('public.school_subject_rules', 'select, insert, update, delete');
select private.expose_table('public.school_subject_rule_members', 'select, insert, update, delete');

create policy "Members of the school can see what it offers"
  on public.subject_offerings for select to authenticated
  using (private.is_member(school_id));
create policy "School admins can add offerings"
  on public.subject_offerings for insert to authenticated
  with check (private.is_school_admin(school_id));
create policy "School admins can change offerings"
  on public.subject_offerings for update to authenticated
  using (private.is_school_admin(school_id))
  with check (private.is_school_admin(school_id));
create policy "School admins can remove offerings"
  on public.subject_offerings for delete to authenticated
  using (private.is_school_admin(school_id));

create policy "Members of the school can see its subject rules"
  on public.school_subject_rules for select to authenticated
  using (private.is_member(school_id));
create policy "School admins can add subject rules"
  on public.school_subject_rules for insert to authenticated
  with check (private.is_school_admin(school_id));
create policy "School admins can change subject rules"
  on public.school_subject_rules for update to authenticated
  using (private.is_school_admin(school_id))
  with check (private.is_school_admin(school_id));
create policy "School admins can remove subject rules"
  on public.school_subject_rules for delete to authenticated
  using (private.is_school_admin(school_id));

create policy "Members of the school can see its subject rule members"
  on public.school_subject_rule_members for select to authenticated
  using (private.is_member(school_id));
create policy "School admins can add subject rule members"
  on public.school_subject_rule_members for insert to authenticated
  with check (private.is_school_admin(school_id));
create policy "School admins can change subject rule members"
  on public.school_subject_rule_members for update to authenticated
  using (private.is_school_admin(school_id))
  with check (private.is_school_admin(school_id));
create policy "School admins can remove subject rule members"
  on public.school_subject_rule_members for delete to authenticated
  using (private.is_school_admin(school_id));

-- ---------------------------------------------------------------------------------
-- 4. Demo data
-- ---------------------------------------------------------------------------------

-- What the demo generator decided about each made-up learner, kept so later slices
-- (marks, study time, attendance) build on the same people: ability, aptitudes and
-- the walkthrough story for the five hero learners. Private: never shown to anyone.
create table private.demo_learner_traits (
  profile_id uuid primary key references public.profiles (id) on delete cascade,
  school_id uuid not null references public.schools (id) on delete cascade,
  sex text not null check (sex in ('F', 'M')),
  ability numeric(5, 2) not null,
  maths_aptitude numeric(5, 2) not null,
  language_aptitude numeric(5, 2) not null,
  elective_profile text not null check (elective_profile in ('science', 'commerce', 'humanities', 'arts')),
  hero text
);

create index demo_learner_traits_school_id_idx on private.demo_learner_traits (school_id);

revoke all on table private.demo_learner_traits from public, anon, authenticated;

comment on table private.demo_learner_traits is
  'Demo schools only: the generator''s hidden traits per learner, used to generate marks and activity in later slices.';

-- Removes a demo school and everyone who belongs only to it. Refuses real schools.
-- Logins (auth.users) are kept: a person whose profile goes simply has no school
-- until a roster lists their email again.
create function private.demo_remove_school(p_slug text)
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_school uuid;
  v_group uuid;
  v_profiles uuid[];
begin
  select s.id, s.school_group_id into v_school, v_group
  from public.schools s
  where s.slug = p_slug;

  if v_school is null then
    return;
  end if;
  if not (select s.is_demo from public.schools s where s.id = v_school) then
    raise exception 'School % is not a demo school; refusing to remove it', p_slug
      using errcode = '42501';
  end if;

  select coalesce(array_agg(distinct m.profile_id), '{}') into v_profiles
  from public.school_memberships m
  where m.school_id = v_school;

  delete from public.parent_consents where school_id = v_school;
  delete from public.student_subject_goals where school_id = v_school;
  delete from public.student_study_profiles where school_id = v_school;
  delete from public.teaching_allocations where school_id = v_school;
  delete from public.enrolments where school_id = v_school;
  delete from public.class_subjects where school_id = v_school;
  delete from public.classes where school_id = v_school;
  delete from public.school_subject_rules where school_id = v_school;
  delete from public.subject_offerings where school_id = v_school;
  delete from public.subjects where school_id = v_school;
  delete from public.guardianships where school_id = v_school;
  delete from public.school_memberships where school_id = v_school;
  delete from public.academic_years where school_id = v_school;
  delete from public.schools where id = v_school;

  if not exists (select 1 from public.schools s where s.school_group_id = v_group) then
    delete from public.school_groups where id = v_group;
  end if;

  -- People who now belong nowhere. Anyone still at another school, or on Chom's own
  -- staff, stays.
  delete from public.profiles p
  where p.id = any (v_profiles)
    and not exists (select 1 from public.school_memberships m where m.profile_id = p.id)
    and not exists (select 1 from public.parent_consents c
                    where c.parent_profile_id = p.id or c.student_profile_id = p.id)
    and not exists (select 1 from private.platform_staff s where s.profile_id = p.id);
end;
$$;

revoke execute on function private.demo_remove_school(text) from public;

comment on function private.demo_remove_school(text) is
  'Removes a demo school (is_demo) with its classes, roster and answers, and the people who belong only to it.';

-- Loads Styfe School: the 3-term demo school from the demo data brief, Grades 10-12.
-- Replaces any Styfe already there. Deterministic: the same people every time.
--
-- p_logins sets the emails of the people the demo is shown with (they need real
-- mailboxes to receive sign-in codes). Keys:
--   maths_teacher    the Head of Mathematics (Grade 11-12 Maths, Further Studies Maths)
--   english_teacher  the Head of English (Grade 11-12 English, Further Studies English)
--   science_teacher  the Physical Sciences teacher (all grades)
--   thando_parent    a second guardian for Thando Mokoena, the at-risk hero learner
-- Anyone not given gets a made-up address that receives nothing.
--
-- Learner and staff emails are on styfe.co.za; parents' are on example.com (reserved:
-- it can never deliver mail). Phone numbers start +27 00, which no real number does.
create function private.demo_load_styfe(p_logins jsonb default '{}')
returns uuid
language plpgsql
set search_path = ''
as $$
declare
  v_curriculum uuid;
  v_group uuid;
  v_school uuid;
  v_year uuid;
  v_id uuid;
  v_need int;
  v_grade int;
  v_letter text;
  v_rule uuid;
  r record;
  -- Made-up names for a South African school. Combinations are random, so no real
  -- person is described.
  f_names text[] := array[
    'Lerato', 'Naledi', 'Zanele', 'Ayanda', 'Palesa', 'Nomvula', 'Kgomotso', 'Refilwe',
    'Busisiwe', 'Lindiwe', 'Nandi', 'Siphesihle', 'Zoe', 'Emma', 'Mia', 'Chloe',
    'Jessica', 'Megan', 'Kayla', 'Tayla', 'Leah', 'Hannah', 'Priya', 'Anisha', 'Kavya',
    'Fatima', 'Zainab', 'Yasmin', 'Amira', 'Riana', 'Marike', 'Anri', 'Carla', 'Nicole',
    'Tamryn', 'Bianca', 'Keabetswe', 'Mbali', 'Khanyisile', 'Precious', 'Olwethu',
    'Dineo', 'Boitumelo', 'Lesedi', 'Tumi', 'Imaan', 'Sarah', 'Grace'];
  m_names text[] := array[
    'Thabo', 'Lwazi', 'Sibusiso', 'Mandla', 'Kagiso', 'Tshepo', 'Bongani', 'Themba',
    'Andile', 'Musa', 'Karabo', 'Neo', 'Junaid', 'Yusuf', 'Ashwin', 'Rohan', 'Dev',
    'Kiran', 'Ruan', 'Pieter', 'Johan', 'Wian', 'Dewald', 'Stefan', 'Jaco', 'Matthew',
    'Joshua', 'Nathan', 'Luke', 'Caleb', 'Aiden', 'Ryan', 'Jordan', 'Zaid', 'Ismail',
    'Tariq', 'Mpho', 'Lungelo', 'Siyabonga', 'Vusi', 'Khaya', 'Lethabo', 'Ofentse',
    'Daniel', 'Adam', 'Reza', 'Kabelo', 'Tiaan'];
  surnames text[] := array[
    'Nkosi', 'Khumalo', 'Mthembu', 'Zulu', 'Molefe', 'Mahlangu', 'Sithole', 'Naidoo',
    'Pillay', 'Govender', 'Reddy', 'Moodley', 'Chetty', 'Botha', 'Pretorius', 'Venter',
    'du Plessis', 'Smit', 'Nel', 'Coetzee', 'Fourie', 'Steyn', 'Kruger', 'Hendricks',
    'Petersen', 'Williams', 'Abrahams', 'Isaacs', 'Brown', 'Taylor', 'Wilson', 'Jones',
    'Cohen', 'Levin', 'Mabaso', 'Shabalala', 'Radebe', 'Masilela', 'Modise', 'Sebola',
    'Maseko', 'Ngcobo', 'Cele', 'Mkhize', 'Baloyi', 'Maluleke', 'Chauke', 'Mathebula',
    'Ismail', 'Moosa', 'Singh', 'Joubert', 'Marais', 'Daniels', 'Mokwena', 'Tshabalala'];
  adult_f text[] := array[
    'Nomsa', 'Thandiwe', 'Busi', 'Lindi', 'Puleng', 'Mpho', 'Zodwa', 'Sharon', 'Michelle',
    'Karen', 'Sunita', 'Kamala', 'Nadia', 'Shireen', 'Elmarie', 'Annelie', 'Lizette',
    'Debbie', 'Rachel', 'Ayesha', 'Gugu', 'Nthabiseng', 'Ruth', 'Fiona'];
  adult_m text[] := array[
    'Sipho', 'Mandla', 'Jabulani', 'Themba', 'Tebogo', 'Vusumuzi', 'Kevin', 'Grant',
    'Craig', 'Rajesh', 'Suresh', 'Faiek', 'Riaan', 'Hennie', 'Gerhard', 'Mark', 'David',
    'Anwar', 'Bheki', 'Lucky', 'Pule', 'Brendan', 'Neville', 'Shaun'];
begin
  perform private.demo_remove_school('styfe');
  perform setseed(0.20261107);

  select c.id into v_curriculum from public.curricula c where c.code = 'IEB';
  if v_curriculum is null then
    raise exception 'The IEB curriculum is missing';
  end if;

  -- School, group and year -------------------------------------------------------

  insert into public.school_groups (name, slug) values ('Styfe', 'styfe') returning id into v_group;
  insert into public.schools (name, slug, school_group_id, is_demo)
  values ('Styfe School', 'styfe', v_group, true)
  returning id into v_school;
  insert into public.academic_years (school_id, label, starts_on, ends_on, curriculum_id, is_current)
  values (v_school, '2026', '2026-01-14', '2026-12-04', v_curriculum, true)
  returning id into v_year;

  -- Subjects and what Styfe offers (brief section 3) ------------------------------

  drop table if exists pg_temp.demo_subjects;
  create temp table demo_subjects (
    key text primary key, name text not null, catalogue_name text not null,
    kind public.offering_kind not null, block text, min_grade int not null, max_grade int not null,
    id uuid
  );
  insert into demo_subjects (key, name, catalogue_name, kind, block, min_grade, max_grade) values
    ('eng',  'English Home Language',               'English Home Language',               'fundamental', null, 10, 12),
    ('afr',  'Afrikaans First Additional Language', 'Afrikaans First Additional Language', 'fundamental', null, 10, 12),
    ('math', 'Mathematics',                         'Mathematics',                         'fundamental', null, 10, 12),
    ('ml',   'Mathematical Literacy',               'Mathematical Literacy',               'fundamental', null, 10, 12),
    ('lo',   'Life Orientation',                    'Life Orientation',                    'fundamental', null, 10, 12),
    ('ps',   'Physical Sciences',                   'Physical Sciences',                   'elective', 'A', 10, 12),
    ('acc',  'Accounting',                          'Accounting',                          'elective', 'A', 10, 12),
    ('hist', 'History',                             'History',                             'elective', 'A', 10, 12),
    ('va',   'Visual Arts',                         'Visual Arts',                         'elective', 'A', 10, 12),
    ('ls',   'Life Sciences',                       'Life Sciences',                       'elective', 'B', 10, 12),
    ('bs',   'Business Studies',                    'Business Studies',                    'elective', 'B', 10, 12),
    ('da',   'Dramatic Arts',                       'Dramatic Arts',                       'elective', 'B', 10, 12),
    ('cat',  'Computer Applications Technology',    'Computer Applications Technology',    'elective', 'B', 10, 12),
    ('geo',  'Geography',                           'Geography',                           'elective', 'C', 10, 12),
    ('econ', 'Economics',                           'Economics',                           'elective', 'C', 10, 12),
    ('it',   'Information Technology',              'Information Technology',              'elective', 'C', 10, 12),
    ('des',  'Design',                              'Design',                              'elective', 'C', 10, 12),
    ('fr',   'French Second Additional Language',   'French Second Additional Language',   'extra',    null, 10, 12),
    ('fsm',  'Further Studies Mathematics',         'Advanced Programme Mathematics',      'extra',    null, 11, 12),
    ('fse',  'Further Studies English',             'Advanced Programme English',          'extra',    null, 11, 12);

  for r in select * from demo_subjects loop
    insert into public.subjects (school_id, name, curriculum_subject_id)
    values (
      v_school, r.name,
      (select cs.id from public.curriculum_subjects cs
       where cs.curriculum_id = v_curriculum and cs.name = r.catalogue_name)
    )
    returning id into v_id;
    if not exists (select 1 from public.subjects s where s.id = v_id and s.curriculum_subject_id is not null) then
      raise exception 'Catalogue subject % is missing', r.catalogue_name;
    end if;
    update demo_subjects set id = v_id where key = r.key;
    insert into public.subject_offerings (school_id, academic_year_id, subject_id, kind, block, min_grade, max_grade)
    values (v_school, v_year, v_id, r.kind, r.block, r.min_grade, r.max_grade);
  end loop;

  -- Styfe's own rules. Grades 11-12 may take Mathematics and Mathematical Literacy
  -- together as the IEB package, so they exclude each other in Grade 10 only.
  insert into public.school_subject_rules (school_id, rule_type, min_grade, max_grade, description)
  values (v_school, 'requires', 10, 12, 'Information Technology requires Mathematics')
  returning id into v_rule;
  insert into public.school_subject_rule_members (rule_id, school_id, subject_id, member_role)
  select v_rule, v_school, s.id, case s.key when 'it' then 'subject' else 'required' end
  from demo_subjects s where s.key in ('it', 'math');

  insert into public.school_subject_rules (school_id, rule_type, min_grade, max_grade, description)
  values (v_school, 'requires', 10, 12, 'Physical Sciences requires Mathematics')
  returning id into v_rule;
  insert into public.school_subject_rule_members (rule_id, school_id, subject_id, member_role)
  select v_rule, v_school, s.id, case s.key when 'ps' then 'subject' else 'required' end
  from demo_subjects s where s.key in ('ps', 'math');

  insert into public.school_subject_rules (school_id, rule_type, min_grade, max_grade, description)
  values (v_school, 'mutually_exclusive', 10, 12, 'Mathematical Literacy learners cannot take Physical Sciences')
  returning id into v_rule;
  insert into public.school_subject_rule_members (rule_id, school_id, subject_id)
  select v_rule, v_school, s.id from demo_subjects s where s.key in ('ml', 'ps');

  insert into public.school_subject_rules (school_id, rule_type, min_grade, max_grade, description)
  values (v_school, 'mutually_exclusive', 10, 12, 'Mathematical Literacy learners cannot take Information Technology')
  returning id into v_rule;
  insert into public.school_subject_rule_members (rule_id, school_id, subject_id)
  select v_rule, v_school, s.id from demo_subjects s where s.key in ('ml', 'it');

  insert into public.school_subject_rules (school_id, rule_type, min_grade, max_grade, description)
  values (v_school, 'mutually_exclusive', 10, 10,
          'Mathematics or Mathematical Literacy (both only as the Grade 11-12 package)')
  returning id into v_rule;
  insert into public.school_subject_rule_members (rule_id, school_id, subject_id)
  select v_rule, v_school, s.id from demo_subjects s where s.key in ('math', 'ml');

  -- Staff: 23, every offered subject covered (brief section 8) --------------------

  drop table if exists pg_temp.demo_staff;
  create temp table demo_staff (
    key text primary key, full_name text not null, preferred_name text not null,
    email text not null, job_title text, is_admin boolean not null default false,
    is_teacher boolean not null default true, profile_id uuid
  );
  insert into demo_staff (key, full_name, preferred_name, email, job_title, is_admin, is_teacher) values
    ('principal', 'Nomsa Khoza',      'Dr Khoza',      'nomsa.khoza@styfe.co.za',     'Principal',            true,  false),
    ('deputy',    'Gareth Fourie',    'Mr Fourie',     'gareth.fourie@styfe.co.za',   'Deputy Principal',     true,  true),
    ('math1',     'Dan Joffe',        'Mr Joffe',      coalesce(p_logins ->> 'maths_teacher', 'dan.joffe@styfe.co.za'),
                                                                                      'Head of Mathematics',  false, true),
    ('math2',     'Precious Mahlangu','Ms Mahlangu',   'precious.mahlangu@styfe.co.za', null,                 false, true),
    ('math3',     'Ruan Steyn',       'Mr Steyn',      'ruan.steyn@styfe.co.za',      null,                   false, true),
    ('eng1',      'Sarah Mitchell',   'Ms Mitchell',   coalesce(p_logins ->> 'english_teacher', 'sarah.mitchell@styfe.co.za'),
                                                                                      'Head of English',      false, true),
    ('eng2',      'Thabo Mokgadi',    'Mr Mokgadi',    'thabo.mokgadi@styfe.co.za',   null,                   false, true),
    ('afr1',      'Anri Pretorius',   'Me Pretorius',  'anri.pretorius@styfe.co.za',  'Head of Afrikaans',    false, true),
    ('afr2',      'Pieter Nel',       'Mnr Nel',       'pieter.nel@styfe.co.za',      null,                   false, true),
    ('lo',        'Sibusiso Zwane',   'Mr Zwane',      'sibusiso.zwane@styfe.co.za',  null,                   false, true),
    ('ps',        'Kavitha Naidoo',   'Dr Naidoo',     coalesce(p_logins ->> 'science_teacher', 'kavitha.naidoo@styfe.co.za'),
                                                                                      'Head of Science',      false, true),
    ('ls',        'Lerato Molefe',    'Ms Molefe',     'lerato.molefe@styfe.co.za',   null,                   false, true),
    ('geo',       'Johan Venter',     'Mr Venter',     'johan.venter@styfe.co.za',    null,                   false, true),
    ('acc',       'Fatima Isaacs',    'Ms Isaacs',     'fatima.isaacs@styfe.co.za',   'Head of Commerce',     false, true),
    ('bs',        'Kagiso Tau',       'Mr Tau',        'kagiso.tau@styfe.co.za',      null,                   false, true),
    ('econ',      'Hannah Levin',     'Ms Levin',      'hannah.levin@styfe.co.za',    null,                   false, true),
    ('hist',      'Andile Ngcobo',    'Mr Ngcobo',     'andile.ngcobo@styfe.co.za',   null,                   false, true),
    ('da',        'Chloe Williams',   'Ms Williams',   'chloe.williams@styfe.co.za',  null,                   false, true),
    ('it',        'Rohan Pillay',     'Mr Pillay',     'rohan.pillay@styfe.co.za',    null,                   false, true),
    ('cat',       'Bianca Smit',      'Ms Smit',       'bianca.smit@styfe.co.za',     null,                   false, true),
    ('va',        'Zanele Mkhize',    'Ms Mkhize',     'zanele.mkhize@styfe.co.za',   'Head of Arts',         false, true),
    ('des',       'Matthew Adams',    'Mr Adams',      'matthew.adams@styfe.co.za',   null,                   false, true),
    ('fr',        'Claire Dubois',    'Mme Dubois',    'claire.dubois@styfe.co.za',   null,                   false, true);

  update demo_staff set email = lower(trim(email));

  for r in select * from demo_staff loop
    insert into public.profiles (full_name, preferred_name)
    values (r.full_name, r.preferred_name)
    returning id into v_id;
    update demo_staff set profile_id = v_id where key = r.key;
    if r.is_admin then
      insert into public.school_memberships (school_id, profile_id, role, email, job_title, phone)
      values (v_school, v_id, 'school_admin', r.email, r.job_title,
              '+27 00 ' || lpad((floor(random() * 1000))::int::text, 3, '0') || ' '
                        || lpad((floor(random() * 10000))::int::text, 4, '0'));
    end if;
    if r.is_teacher then
      insert into public.school_memberships (school_id, profile_id, role, email, job_title, phone)
      values (v_school, v_id, 'teacher', r.email, coalesce(r.job_title, 'Teacher'),
              '+27 00 ' || lpad((floor(random() * 1000))::int::text, 3, '0') || ' '
                        || lpad((floor(random() * 10000))::int::text, 4, '0'));
    end if;
  end loop;

  -- Learners: Grades 10-12, classes A and B, 25 each (brief section 8) -------------

  drop table if exists pg_temp.demo_learners;
  create temp table demo_learners (
    n serial primary key,
    grade int not null,
    letter text not null,
    first_name text not null,
    last_name text not null,
    sex text not null,
    ability numeric not null,
    maths_apt numeric not null,
    lang_apt numeric not null,
    track text,          -- 'math' or 'ml'
    profile text,        -- science, commerce, humanities, arts
    block_a text, block_b text, block_c text,
    french boolean not null default false,
    fs_maths boolean not null default false,
    fs_eng boolean not null default false,
    package boolean not null default false,  -- Mathematics + Mathematical Literacy
    hero text,
    email text,
    profile_id uuid
  );

  -- The five Styfe hero learners, fixed for the walkthrough.
  insert into demo_learners (grade, letter, first_name, last_name, sex, ability, maths_apt, lang_apt,
                             track, profile, block_a, block_b, block_c, fs_maths, package, hero) values
    (12, 'A', 'Thando', 'Mokoena',        'F', 74, 4,  2, 'math', 'science',   'ps',   'ls', 'geo',  false, false,
     'At risk: Maths and Physical Sciences slip about 8 points by June and 16 by prelims; study time falls from about 240 to 80 minutes a week from May. Provisional offer: UCT Mechanical Engineering.'),
    (10, 'B', 'Liam',   'Jacobs',         'M', 58, -8, 0, 'math', 'commerce',  'acc',  'bs', 'econ', false, false,
     'AI tutor success: Maths rises from 38% to about 67% as study time climbs from 60 to 320 minutes a week.'),
    (11, 'A', 'Sipho',  'Ndlovu',         'M', 88, 6,  2, 'math', 'science',   'ps',   'ls', 'it',   true,  false,
     'Top achiever, about 90% average. Soccer 1st XI captain. Wrote IeBT Maths and Physics.'),
    (11, 'B', 'Aaliyah','Davids',         'F', 60, -12, 4, 'math', 'commerce', 'acc',  'bs', 'geo',  false, true,
     'Maths + Maths Literacy package: Maths about 44%, Maths Literacy about 70%.'),
    (12, 'B', 'Ethan',  'van der Merwe',  'M', 58, -4, 0, 'ml',   'humanities','hist', 'bs', 'des',  false, false,
     'Attendance alert: about 12 days absent June-August; marks dip about 7 points.');

  -- Everyone else: random names and abilities, mostly 55-75.
  for v_grade in 10..12 loop
    foreach v_letter in array array['A', 'B'] loop
      select 25 - count(*) into v_need from demo_learners where grade = v_grade and letter = v_letter;
      for i in 1..v_need loop
        insert into demo_learners (grade, letter, first_name, last_name, sex, ability, maths_apt, lang_apt)
        select v_grade, v_letter,
               case when s = 'F' then f_names[1 + floor(random() * array_length(f_names, 1))::int]
                    else m_names[1 + floor(random() * array_length(m_names, 1))::int] end,
               surnames[1 + floor(random() * array_length(surnames, 1))::int],
               s,
               -- Normal(64, 9), from Box-Muller, kept between 35 and 95.
               greatest(35, least(95, round((64 + 9 * sqrt(-2 * ln(1 - random())) * cos(2 * pi() * random()))::numeric, 2))),
               round((7 * sqrt(-2 * ln(1 - random())) * cos(2 * pi() * random()))::numeric, 2),
               round((5 * sqrt(-2 * ln(1 - random())) * cos(2 * pi() * random()))::numeric, 2)
        from (select case when random() < 0.5 then 'F' else 'M' end as s) x;
      end loop;
    end loop;
  end loop;

  -- Mathematics or Mathematical Literacy, by maths ability: about 70/30 in Grade 10,
  -- 66/34 in Grade 11, 62/38 in Grade 12 (heroes count towards the split).
  update demo_learners l
  set track = case when ranked.rk <= ranked.maths_places then 'math' else 'ml' end
  from (
    select x.n,
           row_number() over (partition by x.grade order by x.ability + x.maths_apt + 6 * random() desc) as rk,
           round(50 * case x.grade when 10 then 0.70 when 11 then 0.66 else 0.62 end)::int
             - (select count(*) from demo_learners h where h.grade = x.grade and h.hero is not null and h.track = 'math')::int
             as maths_places
    from demo_learners x
    where x.hero is null
  ) ranked
  where l.n = ranked.n;

  -- Elective profile: Maths learners science 38%, commerce 32%, humanities 15%,
  -- arts 15%; Maths Literacy learners commerce 35%, humanities 40%, arts 25%.
  update demo_learners
  set profile = case
    when track = 'math' then case
      when p < 0.38 then 'science' when p < 0.70 then 'commerce' when p < 0.85 then 'humanities' else 'arts' end
    else case
      when p < 0.35 then 'commerce' when p < 0.75 then 'humanities' else 'arts' end
    end
  from (select n as pn, random() as p from demo_learners) pr
  where pn = n and hero is null;

  -- One elective per block, following the profile.
  update demo_learners
  set block_a = case profile when 'science' then 'ps' when 'commerce' then 'acc'
                             when 'humanities' then 'hist' else 'va' end,
      block_b = case profile
                  when 'science' then case when q1 < 0.8 then 'ls' else 'cat' end
                  when 'commerce' then 'bs'
                  when 'humanities' then case when q1 < 0.4 then 'ls' when q1 < 0.7 then 'bs' else 'da' end
                  else case when q1 < 0.7 then 'da' else 'cat' end end,
      block_c = case profile
                  when 'science' then case when q2 < 0.6 then 'geo' else 'it' end
                  when 'commerce' then case when q2 < 0.75 then 'econ' else 'geo' end
                  when 'humanities' then 'geo'
                  else 'des' end
  from (select n as qn, random() as q1, random() as q2 from demo_learners) qs
  where qn = n and hero is null;

  -- Extras. French: about 5 per grade.
  update demo_learners set french = true
  where n in (
    select n from (
      select n, row_number() over (partition by grade order by random()) as rk
      from demo_learners where hero is null and ability >= 55
    ) x where rk <= 5
  );

  -- Further Studies Mathematics (Grades 11-12): the strongest 4 Maths learners.
  update demo_learners set fs_maths = true
  where n in (
    select n from (
      select n, grade, row_number() over (partition by grade order by ability + maths_apt desc) as rk
      from demo_learners
      where grade >= 11 and track = 'math' and hero is null and not package
    ) x
    where rk <= 4 - (select count(*) from demo_learners h where h.grade = x.grade and h.fs_maths)
  );

  -- Further Studies English (Grades 11-12): the strongest 3 English learners.
  update demo_learners set fs_eng = true
  where n in (
    select n from (
      select n, row_number() over (partition by grade order by ability + lang_apt desc) as rk
      from demo_learners where grade >= 11 and hero is null
    ) x where rk <= 3
  );

  -- Mathematics + Mathematical Literacy package (Grades 11-12): about 3 of the weakest
  -- Maths learners, never with Physical Sciences or IT.
  update demo_learners set package = true
  where n in (
    select n from (
      select n, grade, row_number() over (partition by grade order by ability + maths_apt) as rk
      from demo_learners
      where grade >= 11 and track = 'math' and hero is null and not fs_maths
        and block_a <> 'ps' and block_c <> 'it'
    ) x
    where rk <= 3 - (select count(*) from demo_learners h where h.grade = x.grade and h.package)
  );

  -- Emails: first.last@styfe.co.za, numbered when two learners share a name.
  update demo_learners l
  set email = e.base || case when e.dup > 1 then e.dup::text else '' end || '@styfe.co.za'
  from (
    select n,
           regexp_replace(lower(first_name), '[^a-z]', '', 'g') || '.'
             || regexp_replace(lower(last_name), '[^a-z]', '', 'g') as base,
           row_number() over (
             partition by regexp_replace(lower(first_name), '[^a-z]', '', 'g') || '.'
                          || regexp_replace(lower(last_name), '[^a-z]', '', 'g')
             order by hero is null, n) as dup
    from demo_learners
  ) e
  where e.n = l.n;

  for r in select * from demo_learners order by n loop
    insert into public.profiles (full_name) values (r.first_name || ' ' || r.last_name)
    returning id into v_id;
    update demo_learners set profile_id = v_id where n = r.n;
    insert into public.school_memberships (school_id, profile_id, role, email, date_of_birth, phone)
    values (
      v_school, v_id, 'student', r.email,
      -- Grade 12 learners born in 2008, Grade 11 in 2009, Grade 10 in 2010.
      make_date(2020 - r.grade, 1, 1) + floor(random() * 365)::int,
      '+27 00 ' || lpad((floor(random() * 1000))::int::text, 3, '0') || ' '
                || lpad((floor(random() * 10000))::int::text, 4, '0')
    );
    insert into private.demo_learner_traits
      (profile_id, school_id, sex, ability, maths_aptitude, language_aptitude, elective_profile, hero)
    values (v_id, v_school, r.sex, r.ability, r.maths_apt, r.lang_apt, r.profile, r.hero);
  end loop;

  -- Who takes what ------------------------------------------------------------------

  drop table if exists pg_temp.demo_takes;
  create temp table demo_takes (n int not null, subject text not null, primary key (n, subject));
  insert into demo_takes (n, subject)
  select n, unnest(array['eng', 'afr', 'lo', track, block_a, block_b, block_c]) from demo_learners;
  insert into demo_takes (n, subject) select n, 'ml' from demo_learners where package;
  insert into demo_takes (n, subject) select n, 'fr' from demo_learners where french;
  insert into demo_takes (n, subject) select n, 'fsm' from demo_learners where fs_maths;
  insert into demo_takes (n, subject) select n, 'fse' from demo_learners where fs_eng;

  -- Classes: register classes 10A-12B teach English, Afrikaans and Life Orientation;
  -- Mathematics is taught per register class; every other subject is one group per
  -- grade, split in two when it has more than 28 learners.
  drop table if exists pg_temp.demo_groups;
  create temp table demo_groups (
    n int not null, subject text not null, class_name text not null,
    primary key (n, subject)
  );
  insert into demo_groups (n, subject, class_name)
  select t.n, t.subject,
         case
           when t.subject in ('eng', 'afr', 'lo') then l.grade || l.letter
           when t.subject = 'math' then l.grade || l.letter || ' Mathematics'
           when g.size > 28 then l.grade || ' ' || s.name || ' ' || (1 + (g.rk - 1) % 2)
           else l.grade || ' ' || s.name
         end
  from demo_takes t
  join demo_learners l on l.n = t.n
  join demo_subjects s on s.key = t.subject
  join (
    select t2.n, t2.subject,
           count(*) over (partition by l2.grade, t2.subject) as size,
           row_number() over (partition by l2.grade, t2.subject order by l2.letter, l2.last_name, l2.n) as rk
    from demo_takes t2 join demo_learners l2 on l2.n = t2.n
  ) g on g.n = t.n and g.subject = t.subject;

  drop table if exists pg_temp.demo_classes;
  create temp table demo_classes (
    class_name text primary key, grade int not null, kind public.class_kind not null, id uuid
  );
  insert into demo_classes (class_name, grade, kind)
  select distinct dg.class_name, l.grade,
         case when dg.subject in ('eng', 'afr', 'lo') then 'register'::public.class_kind
              else 'subject_group'::public.class_kind end
  from demo_groups dg join demo_learners l on l.n = dg.n;

  for r in select * from demo_classes order by grade, class_name loop
    insert into public.classes (school_id, academic_year_id, grade, name, kind)
    values (v_school, v_year, r.grade, r.class_name, r.kind)
    returning id into v_id;
    update demo_classes set id = v_id where class_name = r.class_name;
  end loop;

  insert into public.class_subjects (school_id, class_id, subject_id)
  select distinct v_school, c.id, s.id
  from demo_groups dg
  join demo_classes c on c.class_name = dg.class_name
  join demo_subjects s on s.key = dg.subject;

  insert into public.enrolments (school_id, class_id, student_profile_id)
  select distinct v_school, c.id, l.profile_id
  from demo_groups dg
  join demo_classes c on c.class_name = dg.class_name
  join demo_learners l on l.n = dg.n;

  -- Who teaches what. Further Studies goes to the strongest Maths and English teachers.
  insert into public.teaching_allocations (school_id, class_subject_id, teacher_profile_id)
  select v_school, cs.id, st.profile_id
  from public.class_subjects cs
  join public.classes c on c.id = cs.class_id
  join demo_subjects s on s.id = cs.subject_id
  join demo_staff st on st.key = case
    when s.key in ('math', 'fsm') and c.grade >= 11 then 'math1'
    when s.key = 'math' then 'math2'
    when s.key = 'ml' and c.grade = 10 then 'math2'
    when s.key = 'ml' then 'math3'
    when s.key = 'fse' or (s.key = 'eng' and (c.grade = 12 or c.name = '11A')) then 'eng1'
    when s.key = 'eng' then 'eng2'
    when s.key = 'afr' and c.grade >= 11 then 'afr1'
    when s.key = 'afr' then 'afr2'
    when s.key = 'lo' and c.grade = 12 then 'deputy'
    else s.key
  end
  where cs.school_id = v_school;

  -- Parents: one or two per learner (70% have two) ----------------------------------

  drop table if exists pg_temp.demo_parents;
  create temp table demo_parents (
    pn serial primary key, n int not null, relationship public.guardian_relationship not null,
    is_primary boolean not null, full_name text not null, email text, profile_id uuid,
    has_second boolean not null default false
  );

  -- The primary parent: a mother where there are two parents, otherwise a mother three
  -- times in four.
  insert into demo_parents (n, relationship, is_primary, full_name, has_second)
  select x.n,
         case when x.two or x.mum then 'mother'::public.guardian_relationship
              else 'father'::public.guardian_relationship end,
         true,
         case when x.two or x.mum then adult_f[1 + floor(x.r1 * array_length(adult_f, 1))::int]
              else adult_m[1 + floor(x.r1 * array_length(adult_m, 1))::int] end
           || ' ' || x.last_name,
         x.two
  from (
    select l.n, l.last_name, random() < 0.7 as two, random() < 0.75 as mum, random() as r1
    from demo_learners l
  ) x;

  -- The second parent, where there is one. Not for Thando: her second guardian is the
  -- demo's parent login, below.
  insert into demo_parents (n, relationship, is_primary, full_name)
  select p.n, 'father', false,
         adult_m[1 + floor(random() * array_length(adult_m, 1))::int] || ' ' || l.last_name
  from demo_parents p
  join demo_learners l on l.n = p.n
  where p.has_second
    and not (l.first_name = 'Thando' and l.hero is not null);

  -- Thando's second guardian is the demo's parent login.
  insert into demo_parents (n, relationship, is_primary, full_name, email)
  select l.n, 'guardian', false, 'Daniel Joffe', lower(trim(p_logins ->> 'thando_parent'))
  from demo_learners l
  where l.first_name = 'Thando' and l.hero is not null;

  update demo_parents p
  set email = coalesce(p.email,
         e.base || case when e.dup > 1 then e.dup::text else '' end || '@example.com')
  from (
    select pn,
           regexp_replace(lower(split_part(full_name, ' ', 1)), '[^a-z]', '', 'g') || '.'
             || regexp_replace(lower(substr(full_name, strpos(full_name, ' ') + 1)), '[^a-z]', '', 'g') as base,
           row_number() over (
             partition by regexp_replace(lower(split_part(full_name, ' ', 1)), '[^a-z]', '', 'g') || '.'
                          || regexp_replace(lower(substr(full_name, strpos(full_name, ' ') + 1)), '[^a-z]', '', 'g')
             order by pn) as dup
    from demo_parents
  ) e
  where e.pn = p.pn;

  for r in select * from demo_parents order by pn loop
    insert into public.profiles (full_name) values (r.full_name) returning id into v_id;
    update demo_parents set profile_id = v_id where pn = r.pn;
    insert into public.school_memberships (school_id, profile_id, role, email, phone)
    values (v_school, v_id, 'parent', r.email,
            '+27 00 ' || lpad((floor(random() * 1000))::int::text, 3, '0') || ' '
                      || lpad((floor(random() * 10000))::int::text, 4, '0'));
    insert into public.guardianships
      (school_id, parent_profile_id, student_profile_id, relationship, is_primary, status)
    select v_school, v_id, l.profile_id, r.relationship, r.is_primary, 'invited'
    from demo_learners l where l.n = r.n;
  end loop;

  return v_school;
end;
$$;

revoke execute on function private.demo_load_styfe(jsonb) from public;

comment on function private.demo_load_styfe(jsonb) is
  'Loads (or reloads) Styfe School, the 3-term demo school: 23 staff, 150 learners in Grades 10-12, their classes and parents. See docs and the demo data brief.';
