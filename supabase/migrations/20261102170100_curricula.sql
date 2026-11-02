-- Curricula and their official subject catalogues.
--
-- The curriculum is data, not code: IEB is a row today; CAPS and Cambridge are added as
-- rows later without changing any table or app. Schools choose a curriculum per school
-- year (see academic_years) and link their own subjects to catalogue entries.

create table public.curricula (
  id uuid primary key default gen_random_uuid(),
  code text not null unique check (code ~ '^[A-Z][A-Z0-9_]*$'),
  name text not null check (length(trim(name)) > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.curricula is
  'Curricula a school can follow (IEB now; CAPS, Cambridge later). Reference data shared by all schools.';

create table public.curriculum_subjects (
  id uuid primary key default gen_random_uuid(),
  curriculum_id uuid not null references public.curricula (id) on delete restrict,
  name text not null check (length(trim(name)) > 0),
  code text,
  min_grade smallint not null check (min_grade between 0 and 12),
  max_grade smallint not null check (max_grade between 0 and 12),
  -- Cambridge qualifications (IGCSE, AS Level, A Level) belong to a subject, not a grade.
  -- Null for curricula without per-subject levels, such as IEB.
  qualification_level text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (min_grade <= max_grade),
  unique nulls not distinct (curriculum_id, name, qualification_level)
);

comment on table public.curriculum_subjects is
  'Official subject catalogue per curriculum. Schools pick from it when setting up subjects. Grade 0 means Grade R.';

create index curriculum_subjects_curriculum_id_idx on public.curriculum_subjects (curriculum_id);

create trigger curricula_set_updated_at before update on public.curricula
  for each row execute function private.set_updated_at();
create trigger curriculum_subjects_set_updated_at before update on public.curriculum_subjects
  for each row execute function private.set_updated_at();

-- The IEB itself. Its subject list is loaded separately from IEB's official published list.
insert into public.curricula (code, name)
values ('IEB', 'Independent Examinations Board');
