-- Calendars and the curriculum schedule.
--
-- Content is not the calendar (demo data brief, section 1):
--   1. Curriculum units: one ordered list per subject and grade, the same for every
--      school, each with an estimate of teaching weeks. Never tied to a term number.
--   2. A school's calendar: its terms (3 or 4), half-terms and holidays, exam windows,
--      and the date new content stops for each grade.
--   3. The schedule: the units laid out over that school's teaching days. Teachers can
--      pin a unit to dates; regenerating flows the other units around pinned ones.
-- So the same Grade 11 Maths units land in three terms at a 3-term school and four at
-- a 4-term one. Everything downstream (the AI tutor, test readiness, reports) reads
-- the schedule, never a term number.
--
-- Also: a demo clock (schools.demo_today), so a demo school's "today" can stay fixed
-- while real time moves on. Styfe's is Saturday 7 November 2026.

-- ---------------------------------------------------------------------------------
-- 1. Today, per school
-- ---------------------------------------------------------------------------------

alter table public.schools add column demo_today date
  check (demo_today is null or is_demo);

comment on column public.schools.demo_today is
  'Demo schools only: the date the app treats as today, so a demo stays the same as real time moves on.';

-- The school's today: its demo date if it's a demo school with one, otherwise today in
-- South Africa. security invoker: someone who can't see the school gets the real date.
create function public.school_today(p_school_id uuid)
returns date
language sql
stable
set search_path = ''
as $$
  select coalesce(
    (select s.demo_today from public.schools s where s.id = p_school_id),
    (now() at time zone 'Africa/Johannesburg')::date
  )
$$;

revoke execute on function public.school_today(uuid) from public, anon;
grant execute on function public.school_today(uuid) to authenticated;

-- ---------------------------------------------------------------------------------
-- 2. Public holidays (reference data, the same for every school)
-- ---------------------------------------------------------------------------------

create table public.public_holidays (
  country text not null default 'ZA' check (country ~ '^[A-Z]{2}$'),
  holiday_date date not null,
  name text not null check (length(trim(name)) > 0),
  created_at timestamptz not null default now(),
  primary key (country, holiday_date)
);

comment on table public.public_holidays is 'Public holidays. No school on these days.';

select private.expose_table('public.public_holidays', 'select');
create policy "Signed-in users can read public holidays"
  on public.public_holidays for select to authenticated
  using (true);

insert into public.public_holidays (holiday_date, name) values
  ('2026-01-01', 'New Year''s Day'),
  ('2026-03-21', 'Human Rights Day'),
  ('2026-04-03', 'Good Friday'),
  ('2026-04-06', 'Family Day'),
  ('2026-04-27', 'Freedom Day'),
  ('2026-05-01', 'Workers'' Day'),
  ('2026-06-16', 'Youth Day'),
  ('2026-08-10', 'National Women''s Day (observed)'),
  ('2026-09-24', 'Heritage Day'),
  ('2026-12-16', 'Day of Reconciliation'),
  ('2026-12-25', 'Christmas Day'),
  ('2026-12-26', 'Day of Goodwill');

-- ---------------------------------------------------------------------------------
-- 3. A school's calendar
-- ---------------------------------------------------------------------------------

create table public.school_terms (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null,
  academic_year_id uuid not null,
  term_number smallint not null check (term_number between 1 and 4),
  starts_on date not null,
  ends_on date not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_on >= starts_on),
  unique (academic_year_id, term_number),
  foreign key (academic_year_id, school_id)
    references public.academic_years (id, school_id) on delete restrict
);

comment on table public.school_terms is 'A school''s terms in a year: 3 or 4, whatever the school runs.';

create type public.calendar_break_kind as enum ('half_term', 'school_holiday');

create table public.school_calendar_breaks (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null,
  academic_year_id uuid not null,
  kind public.calendar_break_kind not null,
  label text not null check (length(trim(label)) > 0),
  starts_on date not null,
  ends_on date not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_on >= starts_on),
  foreign key (academic_year_id, school_id)
    references public.academic_years (id, school_id) on delete restrict
);

comment on table public.school_calendar_breaks is
  'Days inside a term with no school: half-terms and the school''s own holidays (public holidays are in public_holidays).';

create type public.exam_window_kind as enum (
  'mid_year',        -- Grades 10-12, counts as school-based assessment
  'preliminary',     -- Grade 12 trial exams
  'final_internal',  -- Grades 10-11 school-set finals
  'final_external'   -- Grade 12 IEB NSC finals: external, ignore the school calendar
);

create table public.exam_windows (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null,
  academic_year_id uuid not null,
  kind public.exam_window_kind not null,
  label text not null check (length(trim(label)) > 0),
  min_grade smallint not null check (min_grade between 0 and 12),
  max_grade smallint not null check (max_grade between 0 and 12),
  starts_on date not null,
  ends_on date not null,
  -- Until the official timetable is loaded (e.g. IEB NSC per-subject dates).
  is_approximate boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_on >= starts_on),
  check (min_grade <= max_grade),
  foreign key (academic_year_id, school_id)
    references public.academic_years (id, school_id) on delete restrict
);

comment on table public.exam_windows is 'Exam periods per grade range. No new content is taught during them.';

create table public.grade_content_end_dates (
  school_id uuid not null,
  academic_year_id uuid not null,
  grade smallint not null check (grade between 0 and 12),
  content_ends_on date not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (academic_year_id, grade),
  foreign key (academic_year_id, school_id)
    references public.academic_years (id, school_id) on delete restrict
);

comment on table public.grade_content_end_dates is
  'The last day new content is taught for a grade; revision after that (Grade 12: before prelims).';

create index school_terms_school_id_idx on public.school_terms (school_id);
create index school_terms_academic_year_id_school_id_idx on public.school_terms (academic_year_id, school_id);
create index school_calendar_breaks_school_id_idx on public.school_calendar_breaks (school_id);
create index school_calendar_breaks_academic_year_id_school_id_idx
  on public.school_calendar_breaks (academic_year_id, school_id);
create index exam_windows_school_id_idx on public.exam_windows (school_id);
create index exam_windows_academic_year_id_school_id_idx on public.exam_windows (academic_year_id, school_id);
create index grade_content_end_dates_school_id_idx on public.grade_content_end_dates (school_id);
create index grade_content_end_dates_academic_year_id_school_id_idx
  on public.grade_content_end_dates (academic_year_id, school_id);

-- ---------------------------------------------------------------------------------
-- 4. Curriculum units (reference data, the same for every school)
-- ---------------------------------------------------------------------------------

create table public.curriculum_units (
  id uuid primary key default gen_random_uuid(),
  curriculum_id uuid not null,
  curriculum_subject_id uuid not null,
  grade smallint not null check (grade between 0 and 12),
  position smallint not null check (position > 0),
  title text not null check (length(trim(title)) > 0),
  -- Estimated teaching weeks. 0 for ongoing units (Physical Education), which run
  -- alongside the others all year.
  teaching_weeks numeric(4, 1) not null check (teaching_weeks >= 0),
  is_ongoing boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (is_ongoing = (teaching_weeks = 0)),
  unique (curriculum_subject_id, grade, position),
  foreign key (curriculum_subject_id, curriculum_id)
    references public.curriculum_subjects (id, curriculum_id) on delete restrict
);

comment on table public.curriculum_units is
  'The ordered units of a subject in a grade, with teaching-week estimates. Never tied to a term.';

create index curriculum_units_curriculum_subject_id_curriculum_id_idx
  on public.curriculum_units (curriculum_subject_id, curriculum_id);

select private.expose_table('public.curriculum_units', 'select');
create policy "Signed-in users can read curriculum units"
  on public.curriculum_units for select to authenticated
  using (true);

-- IEB examines on CAPS, so these follow CAPS (brief section 7). Further Studies is
-- stored under the catalogue's "Advanced Programme" names.
insert into public.curriculum_units
  (curriculum_id, curriculum_subject_id, grade, position, title, teaching_weeks, is_ongoing)
select cs.curriculum_id, cs.id, u.grade, u.position, u.title, u.weeks, u.ongoing
from (values
  ('Mathematics', 10, 1, 'Algebraic expressions', 3, false),
  ('Mathematics', 10, 2, 'Exponents', 2, false),
  ('Mathematics', 10, 3, 'Number patterns', 1, false),
  ('Mathematics', 10, 4, 'Equations and inequalities', 3, false),
  ('Mathematics', 10, 5, 'Trigonometry', 4, false),
  ('Mathematics', 10, 6, 'Functions', 4, false),
  ('Mathematics', 10, 7, 'Euclidean geometry', 3, false),
  ('Mathematics', 10, 8, 'Analytical geometry', 2, false),
  ('Mathematics', 10, 9, 'Finance and growth', 2, false),
  ('Mathematics', 10, 10, 'Statistics', 2, false),
  ('Mathematics', 10, 11, 'Measurement', 1, false),
  ('Mathematics', 10, 12, 'Probability', 2, false),
  ('Mathematics', 11, 1, 'Exponents and surds', 3, false),
  ('Mathematics', 11, 2, 'Equations and inequalities', 3, false),
  ('Mathematics', 11, 3, 'Number patterns', 3, false),
  ('Mathematics', 11, 4, 'Analytical geometry', 3, false),
  ('Mathematics', 11, 5, 'Functions', 4, false),
  ('Mathematics', 11, 6, 'Trigonometry: identities and equations', 4, false),
  ('Mathematics', 11, 7, 'Trigonometry: sine, cosine and area rules', 2, false),
  ('Mathematics', 11, 8, 'Measurement', 1, false),
  ('Mathematics', 11, 9, 'Euclidean geometry: circle theorems', 3, false),
  ('Mathematics', 11, 10, 'Finance, growth and decay', 2, false),
  ('Mathematics', 11, 11, 'Probability', 2, false),
  ('Mathematics', 11, 12, 'Statistics', 3, false),
  ('Mathematics', 12, 1, 'Sequences and series', 3, false),
  ('Mathematics', 12, 2, 'Functions and inverse functions', 3, false),
  ('Mathematics', 12, 3, 'Exponential and logarithmic functions', 1, false),
  ('Mathematics', 12, 4, 'Finance, growth and decay', 2, false),
  ('Mathematics', 12, 5, 'Trigonometry: compound and double angles', 4, false),
  ('Mathematics', 12, 6, 'Polynomials', 1, false),
  ('Mathematics', 12, 7, 'Differential calculus', 3, false),
  ('Mathematics', 12, 8, 'Analytical geometry', 3, false),
  ('Mathematics', 12, 9, 'Euclidean geometry: similarity', 3, false),
  ('Mathematics', 12, 10, 'Counting principle and probability', 2, false),
  ('Mathematics', 12, 11, 'Statistics: regression and correlation', 2, false),
  ('Mathematical Literacy', 10, 1, 'Numbers and calculations', 2, false),
  ('Mathematical Literacy', 10, 2, 'Patterns, relationships and representations', 2, false),
  ('Mathematical Literacy', 10, 3, 'Finance: income, expenditure, profit and loss', 3, false),
  ('Mathematical Literacy', 10, 4, 'Measurement', 3, false),
  ('Mathematical Literacy', 10, 5, 'Maps, plans and other representations', 3, false),
  ('Mathematical Literacy', 10, 6, 'Data handling', 3, false),
  ('Mathematical Literacy', 10, 7, 'Probability', 2, false),
  ('Mathematical Literacy', 11, 1, 'Numbers and calculations', 1, false),
  ('Mathematical Literacy', 11, 2, 'Finance: tariff systems, interest, banking, inflation', 4, false),
  ('Mathematical Literacy', 11, 3, 'Measurement', 3, false),
  ('Mathematical Literacy', 11, 4, 'Maps, plans and scale', 3, false),
  ('Mathematical Literacy', 11, 5, 'Data handling', 3, false),
  ('Mathematical Literacy', 11, 6, 'Probability and risk', 2, false),
  ('Mathematical Literacy', 12, 1, 'Finance: taxation, exchange rates, investments', 4, false),
  ('Mathematical Literacy', 12, 2, 'Measurement: volume, surface area, conversions', 3, false),
  ('Mathematical Literacy', 12, 3, 'Maps, plans and models', 3, false),
  ('Mathematical Literacy', 12, 4, 'Data handling and interpretation', 4, false),
  ('Mathematical Literacy', 12, 5, 'Probability and risk', 2, false),
  ('English Home Language', 10, 1, 'Novel study', 6, false),
  ('English Home Language', 10, 2, 'Drama study', 6, false),
  ('English Home Language', 10, 3, 'Poetry', 5, false),
  ('English Home Language', 10, 4, 'Short stories and visual literacy', 3, false),
  ('English Home Language', 10, 5, 'Essay writing', 4, false),
  ('English Home Language', 10, 6, 'Transactional writing', 3, false),
  ('English Home Language', 10, 7, 'Language in context and comprehension', 4, false),
  ('English Home Language', 10, 8, 'Oral: prepared speech', 2, false),
  ('English Home Language', 11, 1, 'Novel study', 6, false),
  ('English Home Language', 11, 2, 'Drama study', 6, false),
  ('English Home Language', 11, 3, 'Poetry', 5, false),
  ('English Home Language', 11, 4, 'Short stories and visual literacy', 3, false),
  ('English Home Language', 11, 5, 'Essay writing', 4, false),
  ('English Home Language', 11, 6, 'Transactional writing', 3, false),
  ('English Home Language', 11, 7, 'Language in context and comprehension', 4, false),
  ('English Home Language', 11, 8, 'Oral: prepared speech', 2, false),
  ('English Home Language', 12, 1, 'Novel study', 6, false),
  ('English Home Language', 12, 2, 'Drama study', 6, false),
  ('English Home Language', 12, 3, 'Poetry', 5, false),
  ('English Home Language', 12, 4, 'Short stories and visual literacy', 3, false),
  ('English Home Language', 12, 5, 'Essay writing', 4, false),
  ('English Home Language', 12, 6, 'Transactional writing', 3, false),
  ('English Home Language', 12, 7, 'Language in context and comprehension', 4, false),
  ('English Home Language', 12, 8, 'Listening and reading assessment', 2, false),
  ('Afrikaans First Additional Language', 10, 1, 'Roman/Prosa', 5, false),
  ('Afrikaans First Additional Language', 10, 2, 'Drama of Kortverhale', 4, false),
  ('Afrikaans First Additional Language', 10, 3, 'Poësie', 5, false),
  ('Afrikaans First Additional Language', 10, 4, 'Begripstoets en opsomming', 4, false),
  ('Afrikaans First Additional Language', 10, 5, 'Opstel', 3, false),
  ('Afrikaans First Additional Language', 10, 6, 'Transaksionele skryfwerk', 3, false),
  ('Afrikaans First Additional Language', 10, 7, 'Taalstrukture en -konvensies', 4, false),
  ('Afrikaans First Additional Language', 10, 8, 'Mondeling', 2, false),
  ('Afrikaans First Additional Language', 11, 1, 'Roman/Prosa', 5, false),
  ('Afrikaans First Additional Language', 11, 2, 'Drama of Kortverhale', 4, false),
  ('Afrikaans First Additional Language', 11, 3, 'Poësie', 5, false),
  ('Afrikaans First Additional Language', 11, 4, 'Begripstoets en opsomming', 4, false),
  ('Afrikaans First Additional Language', 11, 5, 'Opstel', 3, false),
  ('Afrikaans First Additional Language', 11, 6, 'Transaksionele skryfwerk', 3, false),
  ('Afrikaans First Additional Language', 11, 7, 'Taalstrukture en -konvensies', 4, false),
  ('Afrikaans First Additional Language', 11, 8, 'Mondeling', 2, false),
  ('Afrikaans First Additional Language', 12, 1, 'Roman/Prosa', 5, false),
  ('Afrikaans First Additional Language', 12, 2, 'Drama of Kortverhale', 4, false),
  ('Afrikaans First Additional Language', 12, 3, 'Poësie', 5, false),
  ('Afrikaans First Additional Language', 12, 4, 'Begripstoets en opsomming', 4, false),
  ('Afrikaans First Additional Language', 12, 5, 'Opstel', 3, false),
  ('Afrikaans First Additional Language', 12, 6, 'Transaksionele skryfwerk', 3, false),
  ('Afrikaans First Additional Language', 12, 7, 'Taalstrukture en -konvensies', 4, false),
  ('Afrikaans First Additional Language', 12, 8, 'Mondeling', 2, false),
  ('Life Orientation', 10, 1, 'Development of the self in society', 5, false),
  ('Life Orientation', 10, 2, 'Social and environmental responsibility', 4, false),
  ('Life Orientation', 10, 3, 'Democracy and human rights', 4, false),
  ('Life Orientation', 10, 4, 'Careers and career choices', 4, false),
  ('Life Orientation', 10, 5, 'Study skills', 3, false),
  ('Life Orientation', 10, 6, 'Physical Education', 0, true),
  ('Life Orientation', 11, 1, 'Development of the self', 4, false),
  ('Life Orientation', 11, 2, 'Social and environmental responsibility', 3, false),
  ('Life Orientation', 11, 3, 'Democracy and human rights', 4, false),
  ('Life Orientation', 11, 4, 'Careers: world of work', 4, false),
  ('Life Orientation', 11, 5, 'Study skills', 2, false),
  ('Life Orientation', 11, 6, 'Physical Education', 0, true),
  ('Life Orientation', 12, 1, 'Development of the self', 4, false),
  ('Life Orientation', 12, 2, 'Social responsibility', 3, false),
  ('Life Orientation', 12, 3, 'Democracy and human rights', 3, false),
  ('Life Orientation', 12, 4, 'Careers: tertiary applications and bursaries', 5, false),
  ('Life Orientation', 12, 5, 'Study and exam skills', 3, false),
  ('Life Orientation', 12, 6, 'Physical Education', 0, true),
  ('Physical Sciences', 10, 1, 'Matter and classification', 2, false),
  ('Physical Sciences', 10, 2, 'States of matter', 1, false),
  ('Physical Sciences', 10, 3, 'Atomic structure', 2, false),
  ('Physical Sciences', 10, 4, 'Periodic table', 1, false),
  ('Physical Sciences', 10, 5, 'Chemical bonding', 2, false),
  ('Physical Sciences', 10, 6, 'Transverse and longitudinal waves, sound', 3, false),
  ('Physical Sciences', 10, 7, 'Electromagnetic radiation', 1, false),
  ('Physical Sciences', 10, 8, 'Physical and chemical change', 1, false),
  ('Physical Sciences', 10, 9, 'Representing chemical change', 1, false),
  ('Physical Sciences', 10, 10, 'Magnetism', 1, false),
  ('Physical Sciences', 10, 11, 'Electrostatics', 1, false),
  ('Physical Sciences', 10, 12, 'Electric circuits', 2, false),
  ('Physical Sciences', 10, 13, 'Reactions in aqueous solution', 2, false),
  ('Physical Sciences', 10, 14, 'Stoichiometry', 2, false),
  ('Physical Sciences', 10, 15, 'Vectors and scalars', 1, false),
  ('Physical Sciences', 10, 16, 'Motion in one dimension', 3, false),
  ('Physical Sciences', 10, 17, 'Mechanical energy', 2, false),
  ('Physical Sciences', 11, 1, 'Vectors in two dimensions', 2, false),
  ('Physical Sciences', 11, 2, 'Newton''s laws', 4, false),
  ('Physical Sciences', 11, 3, 'Atomic combinations and molecular structure', 3, false),
  ('Physical Sciences', 11, 4, 'Intermolecular forces', 2, false),
  ('Physical Sciences', 11, 5, 'Geometrical optics', 2, false),
  ('Physical Sciences', 11, 6, '2D and 3D wavefronts', 1, false),
  ('Physical Sciences', 11, 7, 'Ideal gases', 3, false),
  ('Physical Sciences', 11, 8, 'Quantitative aspects of chemical change', 3, false),
  ('Physical Sciences', 11, 9, 'Electrostatics', 2, false),
  ('Physical Sciences', 11, 10, 'Electromagnetism', 2, false),
  ('Physical Sciences', 11, 11, 'Electric circuits', 2, false),
  ('Physical Sciences', 11, 12, 'Energy and chemical change', 2, false),
  ('Physical Sciences', 11, 13, 'Acid–base and redox reactions', 3, false),
  ('Physical Sciences', 11, 14, 'The lithosphere', 1, false),
  ('Physical Sciences', 12, 1, 'Momentum and impulse', 3, false),
  ('Physical Sciences', 12, 2, 'Vertical projectile motion', 3, false),
  ('Physical Sciences', 12, 3, 'Organic chemistry', 5, false),
  ('Physical Sciences', 12, 4, 'Work, energy and power', 3, false),
  ('Physical Sciences', 12, 5, 'Doppler effect', 1, false),
  ('Physical Sciences', 12, 6, 'Rates of reaction', 2, false),
  ('Physical Sciences', 12, 7, 'Chemical equilibrium', 3, false),
  ('Physical Sciences', 12, 8, 'Acids and bases', 3, false),
  ('Physical Sciences', 12, 9, 'Electric circuits', 3, false),
  ('Physical Sciences', 12, 10, 'Electrochemical reactions', 2, false),
  ('Physical Sciences', 12, 11, 'Electrodynamics', 2, false),
  ('Physical Sciences', 12, 12, 'Photoelectric effect', 1, false),
  ('Physical Sciences', 12, 13, 'Chemical industry: fertilisers', 1, false),
  ('Life Sciences', 10, 1, 'Chemistry of life', 2, false),
  ('Life Sciences', 10, 2, 'Cells', 2, false),
  ('Life Sciences', 10, 3, 'Cell division: mitosis', 2, false),
  ('Life Sciences', 10, 4, 'Plant and animal tissues', 3, false),
  ('Life Sciences', 10, 5, 'Support and transport in plants', 3, false),
  ('Life Sciences', 10, 6, 'Support systems in animals', 2, false),
  ('Life Sciences', 10, 7, 'Transport systems in mammals', 3, false),
  ('Life Sciences', 10, 8, 'Biosphere to ecosystems', 4, false),
  ('Life Sciences', 10, 9, 'Biodiversity and classification', 2, false),
  ('Life Sciences', 10, 10, 'History of life on Earth', 3, false),
  ('Life Sciences', 11, 1, 'Micro-organisms', 3, false),
  ('Life Sciences', 11, 2, 'Plant diversity and reproduction', 2, false),
  ('Life Sciences', 11, 3, 'Animal diversity', 2, false),
  ('Life Sciences', 11, 4, 'Photosynthesis', 3, false),
  ('Life Sciences', 11, 5, 'Animal nutrition', 3, false),
  ('Life Sciences', 11, 6, 'Cellular respiration', 2, false),
  ('Life Sciences', 11, 7, 'Gaseous exchange', 2, false),
  ('Life Sciences', 11, 8, 'Excretion', 2, false),
  ('Life Sciences', 11, 9, 'Population ecology', 3, false),
  ('Life Sciences', 11, 10, 'Human impact on the environment', 4, false),
  ('Life Sciences', 12, 1, 'DNA', 2, false),
  ('Life Sciences', 12, 2, 'Meiosis', 2, false),
  ('Life Sciences', 12, 3, 'Reproduction in vertebrates', 1, false),
  ('Life Sciences', 12, 4, 'Human reproduction', 3, false),
  ('Life Sciences', 12, 5, 'Genetics and inheritance', 4, false),
  ('Life Sciences', 12, 6, 'Nervous system and senses', 4, false),
  ('Life Sciences', 12, 7, 'Endocrine system and homeostasis', 3, false),
  ('Life Sciences', 12, 8, 'Plant responses', 1, false),
  ('Life Sciences', 12, 9, 'Evolution', 4, false),
  ('Life Sciences', 12, 10, 'Human evolution', 3, false),
  ('Accounting', 10, 1, 'Concepts and GAAP', 2, false),
  ('Accounting', 10, 2, 'Journals', 4, false),
  ('Accounting', 10, 3, 'General ledger', 3, false),
  ('Accounting', 10, 4, 'Trial balance', 2, false),
  ('Accounting', 10, 5, 'Salaries and wages', 2, false),
  ('Accounting', 10, 6, 'VAT', 2, false),
  ('Accounting', 10, 7, 'Financial statements', 4, false),
  ('Accounting', 10, 8, 'Analysis and interpretation', 2, false),
  ('Accounting', 10, 9, 'Internal control and ethics', 2, false),
  ('Accounting', 10, 10, 'Budgeting', 2, false),
  ('Accounting', 11, 1, 'Partnerships', 5, false),
  ('Accounting', 11, 2, 'Clubs / non-profits', 3, false),
  ('Accounting', 11, 3, 'Year-end adjustments', 3, false),
  ('Accounting', 11, 4, 'Fixed assets', 2, false),
  ('Accounting', 11, 5, 'Inventory systems', 3, false),
  ('Accounting', 11, 6, 'Reconciliations', 3, false),
  ('Accounting', 11, 7, 'Cash budgets', 2, false),
  ('Accounting', 11, 8, 'Analysis and interpretation', 2, false),
  ('Accounting', 11, 9, 'Ethics', 1, false),
  ('Accounting', 12, 1, 'Companies: ledger', 3, false),
  ('Accounting', 12, 2, 'Companies: financial statements', 4, false),
  ('Accounting', 12, 3, 'Cash flow statement', 3, false),
  ('Accounting', 12, 4, 'Analysis and interpretation', 3, false),
  ('Accounting', 12, 5, 'Audit and governance', 2, false),
  ('Accounting', 12, 6, 'Fixed assets', 1, false),
  ('Accounting', 12, 7, 'Inventory valuation', 2, false),
  ('Accounting', 12, 8, 'Reconciliations', 2, false),
  ('Accounting', 12, 9, 'Manufacturing cost accounting', 3, false),
  ('Accounting', 12, 10, 'Budgeting', 2, false),
  ('Accounting', 12, 11, 'Ethics and internal control', 1, false),
  ('Business Studies', 10, 1, 'Business environments', 3, false),
  ('Business Studies', 10, 2, 'Business sectors', 2, false),
  ('Business Studies', 10, 3, 'Socio-economic issues', 2, false),
  ('Business Studies', 10, 4, 'Entrepreneurial qualities', 2, false),
  ('Business Studies', 10, 5, 'Forms of ownership', 3, false),
  ('Business Studies', 10, 6, 'Business opportunities', 2, false),
  ('Business Studies', 10, 7, 'Creative thinking', 2, false),
  ('Business Studies', 10, 8, 'Business location', 1, false),
  ('Business Studies', 10, 9, 'Business plan', 3, false),
  ('Business Studies', 10, 10, 'Self-management and teamwork', 3, false),
  ('Business Studies', 10, 11, 'Business functions', 4, false),
  ('Business Studies', 11, 1, 'Influences and challenges of business environments', 5, false),
  ('Business Studies', 11, 2, 'Adapting to challenges', 2, false),
  ('Business Studies', 11, 3, 'Entrepreneurship', 2, false),
  ('Business Studies', 11, 4, 'Business idea to venture', 3, false),
  ('Business Studies', 11, 5, 'Presenting business information', 2, false),
  ('Business Studies', 11, 6, 'Stress and crisis management', 2, false),
  ('Business Studies', 11, 7, 'Professionalism and ethics', 2, false),
  ('Business Studies', 11, 8, 'Citizenship roles', 2, false),
  ('Business Studies', 11, 9, 'Production and marketing functions', 4, false),
  ('Business Studies', 12, 1, 'Business legislation (LRA, BCEA, EEA, B-BBEE)', 4, false),
  ('Business Studies', 12, 2, 'Human resources function', 3, false),
  ('Business Studies', 12, 3, 'Business strategies', 3, false),
  ('Business Studies', 12, 4, 'Quality of performance', 2, false),
  ('Business Studies', 12, 5, 'Ethics and professionalism', 2, false),
  ('Business Studies', 12, 6, 'Creative thinking', 2, false),
  ('Business Studies', 12, 7, 'Investment: securities and insurance', 4, false),
  ('Business Studies', 12, 8, 'Management and leadership', 2, false),
  ('Business Studies', 12, 9, 'Team performance and conflict', 2, false),
  ('Business Studies', 12, 10, 'Social responsibility and CSI', 3, false),
  ('Economics', 10, 1, 'Basic concepts', 3, false),
  ('Economics', 10, 2, 'Economic systems', 3, false),
  ('Economics', 10, 3, 'Circular flow', 3, false),
  ('Economics', 10, 4, 'Production possibility curve', 2, false),
  ('Economics', 10, 5, 'Dynamics of markets', 4, false),
  ('Economics', 10, 6, 'Growth and development', 3, false),
  ('Economics', 10, 7, 'Population and labour force', 3, false),
  ('Economics', 10, 8, 'Unemployment', 2, false),
  ('Economics', 10, 9, 'Globalisation', 2, false),
  ('Economics', 11, 1, 'South Africa''s economy', 3, false),
  ('Economics', 11, 2, 'National accounts', 3, false),
  ('Economics', 11, 3, 'Business cycles', 2, false),
  ('Economics', 11, 4, 'Public sector', 3, false),
  ('Economics', 11, 5, 'Foreign exchange markets', 2, false),
  ('Economics', 11, 6, 'Perfect and imperfect markets', 4, false),
  ('Economics', 11, 7, 'Market failures', 2, false),
  ('Economics', 11, 8, 'Growth and development', 3, false),
  ('Economics', 11, 9, 'Industrial development', 2, false),
  ('Economics', 11, 10, 'Economic indicators', 2, false),
  ('Economics', 12, 1, 'Circular flow', 2, false),
  ('Economics', 12, 2, 'Business cycles', 3, false),
  ('Economics', 12, 3, 'Public sector', 3, false),
  ('Economics', 12, 4, 'Foreign exchange', 2, false),
  ('Economics', 12, 5, 'Protectionism and free trade', 2, false),
  ('Economics', 12, 6, 'Perfect markets', 3, false),
  ('Economics', 12, 7, 'Imperfect markets', 3, false),
  ('Economics', 12, 8, 'Market failures', 2, false),
  ('Economics', 12, 9, 'Growth and development', 3, false),
  ('Economics', 12, 10, 'Industrialisation', 2, false),
  ('Economics', 12, 11, 'Inflation', 2, false),
  ('Economics', 12, 12, 'Tourism', 2, false),
  ('Economics', 12, 13, 'Environmental sustainability', 2, false),
  ('Geography', 10, 1, 'Topographic and orthophoto maps', 3, false),
  ('Geography', 10, 2, 'The atmosphere', 3, false),
  ('Geography', 10, 3, 'Plate tectonics', 4, false),
  ('Geography', 10, 4, 'Folding and faulting', 2, false),
  ('Geography', 10, 5, 'Population', 4, false),
  ('Geography', 10, 6, 'Water resources', 3, false),
  ('Geography', 10, 7, 'GIS', 2, false),
  ('Geography', 11, 1, 'Mapwork and GIS', 3, false),
  ('Geography', 11, 2, 'Energy balance and global air circulation', 4, false),
  ('Geography', 11, 3, 'Weather in SA and synoptic charts', 3, false),
  ('Geography', 11, 4, 'Topography and rock types', 4, false),
  ('Geography', 11, 5, 'Development geography', 4, false),
  ('Geography', 11, 6, 'Resources and sustainability', 4, false),
  ('Geography', 12, 1, 'Mid-latitude and tropical cyclones', 4, false),
  ('Geography', 12, 2, 'Local climates', 3, false),
  ('Geography', 12, 3, 'Fluvial processes and drainage', 4, false),
  ('Geography', 12, 4, 'Rural and urban settlement', 4, false),
  ('Geography', 12, 5, 'Economic geography of SA', 5, false),
  ('Geography', 12, 6, 'Mapwork and GIS', 3, false),
  ('History', 10, 1, 'The world around 1600', 3, false),
  ('History', 10, 2, 'European expansion and conquest', 3, false),
  ('History', 10, 3, 'The French Revolution', 3, false),
  ('History', 10, 4, 'Southern Africa after 1750', 4, false),
  ('History', 10, 5, 'Colonial expansion after 1750', 3, false),
  ('History', 10, 6, 'The mineral revolution', 3, false),
  ('History', 10, 7, 'Heritage project', 2, false),
  ('History', 11, 1, 'Communism in Russia 1900–1940', 4, false),
  ('History', 11, 2, 'Capitalism in the USA 1900–1940', 4, false),
  ('History', 11, 3, 'Ideas of race', 4, false),
  ('History', 11, 4, 'Nationalisms', 4, false),
  ('History', 11, 5, 'Apartheid South Africa 1940s–1960s', 4, false),
  ('History', 11, 6, 'Research assignment', 2, false),
  ('History', 12, 1, 'The Cold War', 4, false),
  ('History', 12, 2, 'Independent Africa', 4, false),
  ('History', 12, 3, 'Civil society protests 1950s–1970s', 4, false),
  ('History', 12, 4, 'Civil resistance in SA 1970s–1980s', 4, false),
  ('History', 12, 5, 'End of the Cold War', 3, false),
  ('History', 12, 6, 'Coming of democracy and the TRC', 4, false),
  ('History', 12, 7, 'Research task', 2, false),
  ('Information Technology', 10, 1, 'Hardware and software', 3, false),
  ('Information Technology', 10, 2, 'Networks and communication', 3, false),
  ('Information Technology', 10, 3, 'Data and information management', 2, false),
  ('Information Technology', 10, 4, 'Programming: variables, types, input/output', 5, false),
  ('Information Technology', 10, 5, 'Selection and iteration', 4, false),
  ('Information Technology', 10, 6, 'Social implications', 2, false),
  ('Information Technology', 10, 7, 'PAT phase 1', 3, false),
  ('Information Technology', 11, 1, 'Systems technologies', 2, false),
  ('Information Technology', 11, 2, 'Network and internet technologies', 3, false),
  ('Information Technology', 11, 3, 'Databases and SQL', 4, false),
  ('Information Technology', 11, 4, 'Arrays and strings', 4, false),
  ('Information Technology', 11, 5, 'Object-oriented programming', 4, false),
  ('Information Technology', 11, 6, 'Text files', 2, false),
  ('Information Technology', 11, 7, 'Social implications', 2, false),
  ('Information Technology', 11, 8, 'PAT', 4, false),
  ('Information Technology', 12, 1, 'Database design and normalisation', 3, false),
  ('Information Technology', 12, 2, 'Advanced SQL', 3, false),
  ('Information Technology', 12, 3, 'Advanced OOP', 4, false),
  ('Information Technology', 12, 4, '2D arrays', 3, false),
  ('Information Technology', 12, 5, 'Searching and sorting algorithms', 3, false),
  ('Information Technology', 12, 6, 'Emerging technologies', 2, false),
  ('Information Technology', 12, 7, 'Network security', 2, false),
  ('Information Technology', 12, 8, 'PAT final', 4, false),
  ('Computer Applications Technology', 10, 1, 'Computing concepts', 2, false),
  ('Computer Applications Technology', 10, 2, 'Hardware and software', 3, false),
  ('Computer Applications Technology', 10, 3, 'Word processing', 4, false),
  ('Computer Applications Technology', 10, 4, 'Spreadsheets', 5, false),
  ('Computer Applications Technology', 10, 5, 'Internet and email', 2, false),
  ('Computer Applications Technology', 10, 6, 'Information management', 2, false),
  ('Computer Applications Technology', 10, 7, 'Social implications', 2, false),
  ('Computer Applications Technology', 10, 8, 'PAT', 3, false),
  ('Computer Applications Technology', 11, 1, 'Systems technologies', 2, false),
  ('Computer Applications Technology', 11, 2, 'Network technologies', 2, false),
  ('Computer Applications Technology', 11, 3, 'Spreadsheet functions and lookups', 5, false),
  ('Computer Applications Technology', 11, 4, 'Advanced word processing', 3, false),
  ('Computer Applications Technology', 11, 5, 'Databases', 4, false),
  ('Computer Applications Technology', 11, 6, 'HTML', 3, false),
  ('Computer Applications Technology', 11, 7, 'Information management', 2, false),
  ('Computer Applications Technology', 11, 8, 'PAT', 4, false),
  ('Computer Applications Technology', 12, 1, 'Systems technologies', 2, false),
  ('Computer Applications Technology', 12, 2, 'Internet technologies', 2, false),
  ('Computer Applications Technology', 12, 3, 'Advanced spreadsheets', 5, false),
  ('Computer Applications Technology', 12, 4, 'Database queries, forms and reports', 4, false),
  ('Computer Applications Technology', 12, 5, 'Integrated word processing', 3, false),
  ('Computer Applications Technology', 12, 6, 'HTML', 2, false),
  ('Computer Applications Technology', 12, 7, 'Social implications', 2, false),
  ('Computer Applications Technology', 12, 8, 'PAT final', 4, false),
  ('Visual Arts', 10, 1, 'Sourcebook', 3, false),
  ('Visual Arts', 10, 2, 'Drawing', 5, false),
  ('Visual Arts', 10, 3, '2D/3D practical', 6, false),
  ('Visual Arts', 10, 4, 'Visual culture: prehistory to Renaissance', 4, false),
  ('Visual Arts', 10, 5, 'Art elements and analysis', 3, false),
  ('Visual Arts', 10, 6, 'Exhibition', 2, false),
  ('Visual Arts', 11, 1, 'Sourcebook', 3, false),
  ('Visual Arts', 11, 2, 'Practical body of work 1', 6, false),
  ('Visual Arts', 11, 3, 'Practical body of work 2', 6, false),
  ('Visual Arts', 11, 4, 'Visual culture: Baroque to Modernism', 5, false),
  ('Visual Arts', 11, 5, '20th-century South African art', 3, false),
  ('Visual Arts', 12, 1, 'Sourcebook and concept', 3, false),
  ('Visual Arts', 12, 2, 'Final practical body of work', 10, false),
  ('Visual Arts', 12, 3, 'Contemporary and South African art themes', 6, false),
  ('Visual Arts', 12, 4, 'Exhibition', 3, false),
  ('Dramatic Arts', 10, 1, 'Drama elements', 3, false),
  ('Dramatic Arts', 10, 2, 'Voice and movement', 3, false),
  ('Dramatic Arts', 10, 3, 'Greek theatre', 4, false),
  ('Dramatic Arts', 10, 4, 'Commedia dell''arte', 3, false),
  ('Dramatic Arts', 10, 5, 'Performance PAT', 4, false),
  ('Dramatic Arts', 10, 6, 'Theatre history and set work', 4, false),
  ('Dramatic Arts', 11, 1, 'Elizabethan theatre', 4, false),
  ('Dramatic Arts', 11, 2, 'Realism', 4, false),
  ('Dramatic Arts', 11, 3, 'South African theatre', 3, false),
  ('Dramatic Arts', 11, 4, 'Performance PAT', 4, false),
  ('Dramatic Arts', 11, 5, 'Theatre production', 3, false),
  ('Dramatic Arts', 11, 6, 'Voice and movement', 2, false),
  ('Dramatic Arts', 12, 1, 'Epic theatre', 4, false),
  ('Dramatic Arts', 12, 2, 'Postmodern and physical theatre', 3, false),
  ('Dramatic Arts', 12, 3, 'SA protest and post-1994 theatre', 4, false),
  ('Dramatic Arts', 12, 4, 'PAT and production', 5, false),
  ('Dramatic Arts', 12, 5, 'Set work study', 4, false),
  ('Design', 10, 1, 'Elements and principles', 3, false),
  ('Design', 10, 2, 'Design process', 3, false),
  ('Design', 10, 3, 'Design history', 4, false),
  ('Design', 10, 4, '2D design project', 5, false),
  ('Design', 10, 5, '3D design project', 5, false),
  ('Design', 11, 1, 'Design in social and environmental context', 3, false),
  ('Design', 11, 2, 'Art Nouveau to Modernism', 4, false),
  ('Design', 11, 3, 'Practical project 1', 6, false),
  ('Design', 11, 4, 'Practical project 2', 6, false),
  ('Design', 12, 1, 'Contemporary and SA design', 4, false),
  ('Design', 12, 2, 'Sustainable design', 3, false),
  ('Design', 12, 3, 'Final practical body of work', 10, false),
  ('Design', 12, 4, 'Exhibition', 2, false),
  ('French Second Additional Language', 10, 1, 'Grammaire', 4, false),
  ('French Second Additional Language', 10, 2, 'Compréhension', 4, false),
  ('French Second Additional Language', 10, 3, 'Expression écrite', 4, false),
  ('French Second Additional Language', 10, 4, 'Textes littéraires', 4, false),
  ('French Second Additional Language', 10, 5, 'Oral', 3, false),
  ('French Second Additional Language', 10, 6, 'Culture francophone', 2, false),
  ('French Second Additional Language', 11, 1, 'Grammaire', 4, false),
  ('French Second Additional Language', 11, 2, 'Compréhension', 4, false),
  ('French Second Additional Language', 11, 3, 'Expression écrite', 4, false),
  ('French Second Additional Language', 11, 4, 'Textes littéraires', 4, false),
  ('French Second Additional Language', 11, 5, 'Oral', 3, false),
  ('French Second Additional Language', 11, 6, 'Culture francophone', 2, false),
  ('French Second Additional Language', 12, 1, 'Grammaire', 4, false),
  ('French Second Additional Language', 12, 2, 'Compréhension', 4, false),
  ('French Second Additional Language', 12, 3, 'Expression écrite', 4, false),
  ('French Second Additional Language', 12, 4, 'Textes littéraires', 4, false),
  ('French Second Additional Language', 12, 5, 'Oral', 3, false),
  ('French Second Additional Language', 12, 6, 'Culture francophone', 2, false),
  ('Advanced Programme Mathematics', 11, 1, 'Number theory', 4, false),
  ('Advanced Programme Mathematics', 11, 2, 'Algebra', 4, false),
  ('Advanced Programme Mathematics', 11, 3, 'Differential calculus', 5, false),
  ('Advanced Programme Mathematics', 11, 4, 'Vectors', 4, false),
  ('Advanced Programme Mathematics', 11, 5, 'Euclidean and coordinate geometry', 4, false),
  ('Advanced Programme Mathematics', 11, 6, 'Trigonometry', 3, false),
  ('Advanced Programme Mathematics', 12, 1, 'Integral calculus', 6, false),
  ('Advanced Programme Mathematics', 12, 2, 'Statistics and probability', 4, false),
  ('Advanced Programme Mathematics', 12, 3, 'Matrices', 3, false),
  ('Advanced Programme Mathematics', 12, 4, 'Graph theory', 3, false),
  ('Advanced Programme Mathematics', 12, 5, 'Finance and mathematical modelling', 3, false),
  ('Advanced Programme English', 11, 1, 'Complex poetry', 5, false),
  ('Advanced Programme English', 11, 2, 'Prose', 5, false),
  ('Advanced Programme English', 11, 3, 'Film studies', 4, false),
  ('Advanced Programme English', 11, 4, 'Critical theory and inter-textual analysis', 5, false),
  ('Advanced Programme English', 11, 5, 'Research essay', 4, false),
  ('Advanced Programme English', 12, 1, 'Complex poetry', 5, false),
  ('Advanced Programme English', 12, 2, 'Prose', 5, false),
  ('Advanced Programme English', 12, 3, 'Film studies', 4, false),
  ('Advanced Programme English', 12, 4, 'Critical theory and inter-textual analysis', 5, false),
  ('Advanced Programme English', 12, 5, 'Research essay', 4, false)
) as u (subject, grade, position, title, weeks, ongoing)
join public.curricula c on c.code = 'IEB'
join public.curriculum_subjects cs on cs.curriculum_id = c.id and cs.name = u.subject;

do $$
begin
  if (select count(*) from public.curriculum_units) <> 455 then
    raise exception 'Some curriculum units did not match a catalogue subject';
  end if;
end;
$$;

-- ---------------------------------------------------------------------------------
-- 5. The schedule: units laid out on a school's teaching days
-- ---------------------------------------------------------------------------------

create table public.unit_schedules (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null,
  academic_year_id uuid not null,
  curriculum_unit_id uuid not null references public.curriculum_units (id) on delete restrict,
  starts_on date not null,
  ends_on date not null,
  -- The term the unit starts in.
  term_number smallint check (term_number between 1 and 4),
  -- A teacher's override: kept as is when the schedule is regenerated.
  is_pinned boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_on >= starts_on),
  unique (academic_year_id, curriculum_unit_id),
  foreign key (academic_year_id, school_id)
    references public.academic_years (id, school_id) on delete restrict
);

comment on table public.unit_schedules is
  'When a school teaches each unit this year. Generated from its calendar; pinned rows are teacher overrides.';

create index unit_schedules_school_id_idx on public.unit_schedules (school_id);
create index unit_schedules_academic_year_id_school_id_idx on public.unit_schedules (academic_year_id, school_id);
create index unit_schedules_curriculum_unit_id_idx on public.unit_schedules (curriculum_unit_id);

-- Calendar and schedule: everyone at the school can read them; school admins change
-- them. (Teacher overrides will go through a function that regenerates the rest.)
do $$
declare
  t text;
begin
  foreach t in array array['school_terms', 'school_calendar_breaks', 'exam_windows',
                           'grade_content_end_dates', 'unit_schedules'] loop
    perform private.expose_table(('public.' || t)::regclass, 'select, insert, update, delete');
    execute format(
      'create policy "Members of the school can read it" on public.%I for select to authenticated using (private.is_member(school_id))', t);
    execute format(
      'create policy "School admins can add to it" on public.%I for insert to authenticated with check (private.is_school_admin(school_id))', t);
    execute format(
      'create policy "School admins can change it" on public.%I for update to authenticated using (private.is_school_admin(school_id)) with check (private.is_school_admin(school_id))', t);
    execute format(
      'create policy "School admins can remove from it" on public.%I for delete to authenticated using (private.is_school_admin(school_id))', t);
    execute format(
      'create trigger %I before update on public.%I for each row execute function private.set_updated_at()',
      t || '_set_updated_at', t);
  end loop;
end;
$$;

create trigger unit_schedules_audit after insert or update or delete on public.unit_schedules
  for each row execute function private.audit_row_change();

-- The days a grade is taught new content: weekdays inside a term, up to the grade's
-- content-end date, minus half-terms and school holidays, public holidays and the
-- grade's exam windows.
create function private.teaching_days(p_academic_year_id uuid, p_grade int)
returns setof date
language sql
stable
set search_path = ''
as $$
  select d::date
  from public.school_terms t
  cross join lateral generate_series(
    t.starts_on,
    least(t.ends_on, coalesce(
      (select c.content_ends_on from public.grade_content_end_dates c
       where c.academic_year_id = p_academic_year_id and c.grade = p_grade),
      t.ends_on)),
    interval '1 day') as d
  where t.academic_year_id = p_academic_year_id
    and extract(isodow from d) < 6
    and not exists (select 1 from public.school_calendar_breaks b
                    where b.academic_year_id = p_academic_year_id
                      and d::date between b.starts_on and b.ends_on)
    and not exists (select 1 from public.public_holidays h
                    where h.country = 'ZA' and h.holiday_date = d::date)
    and not exists (select 1 from public.exam_windows e
                    where e.academic_year_id = p_academic_year_id
                      and p_grade between e.min_grade and e.max_grade
                      and d::date between e.starts_on and e.ends_on)
  order by 1
$$;

revoke execute on function private.teaching_days(uuid, int) from public;

-- (Re)generates a school year's schedule (brief section 6). For every subject and grade
-- the school offers, the units are laid out in order over the grade's teaching days,
-- each getting a share of days in proportion to its teaching weeks. Pinned units keep
-- their dates; the others share the days the pinned ones don't use. Ongoing units run
-- from the first teaching day to the last. Returns the number of units scheduled.
create function private.generate_unit_schedule(p_academic_year_id uuid)
returns int
language plpgsql
set search_path = ''
as $$
declare
  v_school uuid;
  v_days date[];
  v_n int;
  v_total numeric;
  v_cum numeric;
  v_a int;
  v_b int;
  v_count int := 0;
  r record;
  u record;
begin
  select y.school_id into v_school from public.academic_years y where y.id = p_academic_year_id;
  if v_school is null then
    raise exception 'No such school year';
  end if;

  delete from public.unit_schedules us
  where us.academic_year_id = p_academic_year_id and not us.is_pinned;

  for r in
    select distinct cu.curriculum_subject_id, cu.grade
    from public.subject_offerings o
    join public.subjects s on s.id = o.subject_id
    join public.curriculum_units cu
      on cu.curriculum_subject_id = s.curriculum_subject_id
     and cu.grade between o.min_grade and o.max_grade
    where o.academic_year_id = p_academic_year_id
  loop
    -- This grade's teaching days, less the days pinned units of this subject hold.
    select array_agg(d order by d) into v_days
    from private.teaching_days(p_academic_year_id, r.grade) d
    where not exists (
      select 1 from public.unit_schedules us
      join public.curriculum_units pu on pu.id = us.curriculum_unit_id
      where us.academic_year_id = p_academic_year_id and us.is_pinned
        and pu.curriculum_subject_id = r.curriculum_subject_id and pu.grade = r.grade
        and d between us.starts_on and us.ends_on);
    v_n := coalesce(array_length(v_days, 1), 0);
    continue when v_n = 0;

    select coalesce(sum(cu.teaching_weeks), 0) into v_total
    from public.curriculum_units cu
    where cu.curriculum_subject_id = r.curriculum_subject_id and cu.grade = r.grade
      and not cu.is_ongoing
      and not exists (select 1 from public.unit_schedules us
                      where us.academic_year_id = p_academic_year_id
                        and us.curriculum_unit_id = cu.id and us.is_pinned);
    v_cum := 0;

    for u in
      select cu.id, cu.teaching_weeks, cu.is_ongoing
      from public.curriculum_units cu
      where cu.curriculum_subject_id = r.curriculum_subject_id and cu.grade = r.grade
        and not exists (select 1 from public.unit_schedules us
                        where us.academic_year_id = p_academic_year_id
                          and us.curriculum_unit_id = cu.id and us.is_pinned)
      order by cu.position
    loop
      if u.is_ongoing then
        v_a := 1;
        v_b := v_n;
      else
        v_a := least(v_n, floor(v_n * v_cum / v_total)::int + 1);
        v_cum := v_cum + u.teaching_weeks;
        v_b := greatest(v_a, least(v_n, floor(v_n * v_cum / v_total)::int));
      end if;
      insert into public.unit_schedules
        (school_id, academic_year_id, curriculum_unit_id, starts_on, ends_on, term_number)
      values (
        v_school, p_academic_year_id, u.id, v_days[v_a], v_days[v_b],
        (select t.term_number from public.school_terms t
         where t.academic_year_id = p_academic_year_id
           and v_days[v_a] between t.starts_on and t.ends_on)
      );
      v_count := v_count + 1;
    end loop;
  end loop;

  return v_count;
end;
$$;

revoke execute on function private.generate_unit_schedule(uuid) from public;

-- ---------------------------------------------------------------------------------
-- 6. Demo: Styfe's calendar (brief section 5), and removal covers the new tables
-- ---------------------------------------------------------------------------------

create or replace function private.demo_remove_school(p_slug text)
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

  delete from public.unit_schedules where school_id = v_school;
  delete from public.exam_windows where school_id = v_school;
  delete from public.grade_content_end_dates where school_id = v_school;
  delete from public.school_calendar_breaks where school_id = v_school;
  delete from public.school_terms where school_id = v_school;
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

-- Styfe's 3-term 2026 calendar (ISASA Central Region guidelines), and its schedule.
create function private.demo_load_styfe_calendar(p_school_id uuid)
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_year uuid;
begin
  select y.id into v_year from public.academic_years y
  where y.school_id = p_school_id and y.is_current;

  update public.schools set demo_today = '2026-11-07' where id = p_school_id;

  insert into public.school_terms (school_id, academic_year_id, term_number, starts_on, ends_on) values
    (p_school_id, v_year, 1, '2026-01-14', '2026-04-10'),
    (p_school_id, v_year, 2, '2026-05-06', '2026-08-07'),
    (p_school_id, v_year, 3, '2026-09-09', '2026-12-04');

  -- Half-terms close at noon the day before; those mornings are still teaching days.
  insert into public.school_calendar_breaks (school_id, academic_year_id, kind, label, starts_on, ends_on) values
    (p_school_id, v_year, 'half_term', 'Term 1 half-term', '2026-02-20', '2026-02-23'),
    (p_school_id, v_year, 'school_holiday', 'Youth Day long weekend', '2026-06-15', '2026-06-15'),
    (p_school_id, v_year, 'half_term', 'Term 2 half-term', '2026-06-29', '2026-07-03'),
    (p_school_id, v_year, 'school_holiday', 'Heritage Day long weekend', '2026-09-25', '2026-09-25'),
    (p_school_id, v_year, 'half_term', 'Term 3 half-term', '2026-10-23', '2026-10-26');

  insert into public.exam_windows
    (school_id, academic_year_id, kind, label, min_grade, max_grade, starts_on, ends_on, is_approximate) values
    (p_school_id, v_year, 'mid_year', 'Mid-year exams', 10, 12, '2026-06-01', '2026-06-19', false),
    (p_school_id, v_year, 'preliminary', 'Grade 12 preliminary exams', 12, 12, '2026-07-20', '2026-08-06', false),
    (p_school_id, v_year, 'final_external', 'IEB NSC final exams', 12, 12, '2026-10-13', '2026-11-26', true),
    (p_school_id, v_year, 'final_internal', 'Grade 10-11 final exams', 10, 11, '2026-11-09', '2026-11-27', false);

  insert into public.grade_content_end_dates (school_id, academic_year_id, grade, content_ends_on) values
    (p_school_id, v_year, 10, '2026-10-30'),
    (p_school_id, v_year, 11, '2026-10-30'),
    (p_school_id, v_year, 12, '2026-07-17');

  perform private.generate_unit_schedule(v_year);
end;
$$;

revoke execute on function private.demo_load_styfe_calendar(uuid) from public;

-- demo_load_styfe() now loads the roster (as before) and then the calendar and schedule.
alter function private.demo_load_styfe(jsonb) rename to demo_load_styfe_roster;

create function private.demo_load_styfe(p_logins jsonb default '{}')
returns uuid
language plpgsql
set search_path = ''
as $$
declare
  v_school uuid;
begin
  v_school := private.demo_load_styfe_roster(p_logins);
  perform private.demo_load_styfe_calendar(v_school);
  return v_school;
end;
$$;

revoke execute on function private.demo_load_styfe(jsonb) from public;

comment on function private.demo_load_styfe(jsonb) is
  'Loads (or reloads) Styfe School, the 3-term demo school: its roster, its 2026 calendar and curriculum schedule, with today fixed at 7 November 2026.';
