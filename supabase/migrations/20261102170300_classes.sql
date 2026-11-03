-- Subjects, classes, who teaches what, and who is in which class.

-- The subjects a school offers. Usually linked to an entry in the official catalogue;
-- custom subjects a school adds itself leave curriculum_subject_id empty.
create table public.subjects (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete restrict,
  name text not null check (length(trim(name)) > 0),
  code text,
  curriculum_subject_id uuid references public.curriculum_subjects (id) on delete restrict,
  ednana_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (school_id, name),
  unique (school_id, ednana_id),
  unique (id, school_id)
);

comment on table public.subjects is 'Subjects a school offers.';

create index subjects_curriculum_subject_id_idx on public.subjects (curriculum_subject_id);

-- A class belongs to one school year. Grade is a number for sorting and filtering
-- (0 = Grade R); name is whatever the school calls it: 10B, 10LSI, Gr10 Maths Ext.
create table public.classes (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null,
  academic_year_id uuid not null,
  grade smallint not null check (grade between 0 and 12),
  name text not null check (length(trim(name)) > 0),
  kind public.class_kind not null default 'register',
  ednana_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (academic_year_id, name),
  unique (school_id, ednana_id),
  unique (id, school_id),
  foreign key (academic_year_id, school_id)
    references public.academic_years (id, school_id) on delete restrict
);

comment on table public.classes is 'A class in one school year. Name is free text; grade is for sorting.';

create index classes_school_id_idx on public.classes (school_id);

-- A subject taught to a class. qualification_level is for curricula where the level
-- belongs to the subject (Cambridge: IGCSE, AS Level, A Level); null for IEB.
create table public.class_subjects (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null,
  class_id uuid not null,
  subject_id uuid not null,
  qualification_level text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique nulls not distinct (class_id, subject_id, qualification_level),
  unique (id, school_id),
  foreign key (class_id, school_id) references public.classes (id, school_id) on delete restrict,
  foreign key (subject_id, school_id) references public.subjects (id, school_id) on delete restrict
);

comment on table public.class_subjects is 'A subject taught to a class.';

create index class_subjects_subject_id_idx on public.class_subjects (subject_id);

-- Which teacher teaches a subject to a class. The teacher must hold the teacher role
-- at the same school.
create table public.teaching_allocations (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null,
  class_subject_id uuid not null,
  teacher_profile_id uuid not null,
  teacher_role public.membership_role not null default 'teacher' check (teacher_role = 'teacher'),
  ednana_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (class_subject_id, teacher_profile_id),
  unique (school_id, ednana_id),
  foreign key (class_subject_id, school_id)
    references public.class_subjects (id, school_id) on delete restrict,
  foreign key (school_id, teacher_profile_id, teacher_role)
    references public.school_memberships (school_id, profile_id, role) on delete restrict
);

comment on table public.teaching_allocations is 'Which teacher teaches a subject to a class.';

create index teaching_allocations_teacher_profile_id_idx on public.teaching_allocations (teacher_profile_id);

-- Which learner is in which class. The learner must hold the student role at the same
-- school as the class.
create table public.enrolments (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null,
  class_id uuid not null,
  student_profile_id uuid not null,
  student_role public.membership_role not null default 'student' check (student_role = 'student'),
  ednana_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (class_id, student_profile_id),
  unique (school_id, ednana_id),
  foreign key (class_id, school_id) references public.classes (id, school_id) on delete restrict,
  foreign key (school_id, student_profile_id, student_role)
    references public.school_memberships (school_id, profile_id, role) on delete restrict
);

comment on table public.enrolments is 'Which learner is in which class.';

create index enrolments_student_profile_id_idx on public.enrolments (student_profile_id);

create trigger subjects_set_updated_at before update on public.subjects
  for each row execute function private.set_updated_at();
create trigger classes_set_updated_at before update on public.classes
  for each row execute function private.set_updated_at();
create trigger class_subjects_set_updated_at before update on public.class_subjects
  for each row execute function private.set_updated_at();
create trigger teaching_allocations_set_updated_at before update on public.teaching_allocations
  for each row execute function private.set_updated_at();
create trigger enrolments_set_updated_at before update on public.enrolments
  for each row execute function private.set_updated_at();
