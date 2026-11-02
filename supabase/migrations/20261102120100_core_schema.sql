-- School-scoped relational schema. Every table that holds school or personal data
-- carries school_id so RLS can enforce tenancy in the database (ADR 0001).

create table public.schools (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  ednana_id text unique,
  created_at timestamptz not null default now()
);

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text not null,
  preferred_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.school_memberships (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  person_id uuid not null references public.profiles (id) on delete cascade,
  role public.app_role not null,
  ednana_id text,
  created_at timestamptz not null default now(),
  unique (school_id, person_id, role)
);

create index school_memberships_person_idx
  on public.school_memberships (person_id);

create index school_memberships_school_idx
  on public.school_memberships (school_id);

create table public.classes (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  name text not null,
  grade text,
  ednana_id text,
  created_at timestamptz not null default now(),
  unique (school_id, name)
);

create index classes_school_idx on public.classes (school_id);

create table public.subjects (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  name text not null,
  short_code text,
  color text,
  created_at timestamptz not null default now(),
  unique (school_id, name)
);

create index subjects_school_idx on public.subjects (school_id);

create table public.class_subjects (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  class_id uuid not null references public.classes (id) on delete cascade,
  subject_id uuid not null references public.subjects (id) on delete cascade,
  teacher_id uuid references public.profiles (id) on delete set null,
  topic text,
  created_at timestamptz not null default now(),
  unique (class_id, subject_id)
);

create index class_subjects_school_idx on public.class_subjects (school_id);
create index class_subjects_teacher_idx on public.class_subjects (teacher_id);

create table public.enrolments (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  class_id uuid not null references public.classes (id) on delete cascade,
  student_id uuid not null references public.profiles (id) on delete cascade,
  ednana_id text,
  created_at timestamptz not null default now(),
  unique (class_id, student_id)
);

create index enrolments_student_idx on public.enrolments (student_id);
create index enrolments_school_idx on public.enrolments (school_id);

create table public.guardianships (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  parent_id uuid not null references public.profiles (id) on delete cascade,
  learner_id uuid not null references public.profiles (id) on delete cascade,
  relationship text,
  ednana_id text,
  created_at timestamptz not null default now(),
  unique (parent_id, learner_id),
  check (parent_id <> learner_id)
);

create index guardianships_parent_idx on public.guardianships (parent_id);
create index guardianships_learner_idx on public.guardianships (learner_id);

create table public.tasks (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  class_subject_id uuid not null references public.class_subjects (id) on delete cascade,
  title text not null,
  body text,
  due_on date,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now()
);

create index tasks_class_subject_idx on public.tasks (class_subject_id);
create index tasks_school_idx on public.tasks (school_id);

create table public.task_completions (
  task_id uuid not null references public.tasks (id) on delete cascade,
  student_id uuid not null references public.profiles (id) on delete cascade,
  school_id uuid not null references public.schools (id) on delete cascade,
  done_at timestamptz not null default now(),
  primary key (task_id, student_id)
);

create index task_completions_student_idx on public.task_completions (student_id);

create table public.assignments (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  class_subject_id uuid not null references public.class_subjects (id) on delete cascade,
  title text not null,
  body text,
  due_on date,
  marks numeric(8, 2),
  status text not null default 'draft'
    check (status in ('draft', 'published', 'closed')),
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now()
);

create index assignments_class_subject_idx on public.assignments (class_subject_id);
create index assignments_school_idx on public.assignments (school_id);

create table public.submissions (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  assignment_id uuid not null references public.assignments (id) on delete cascade,
  student_id uuid not null references public.profiles (id) on delete cascade,
  submitted_at timestamptz,
  mark numeric(8, 2),
  feedback text,
  created_at timestamptz not null default now(),
  unique (assignment_id, student_id)
);

create index submissions_student_idx on public.submissions (student_id);
create index submissions_school_idx on public.submissions (school_id);

create table public.learning_materials (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  class_subject_id uuid not null references public.class_subjects (id) on delete cascade,
  title text not null,
  filename text,
  storage_path text,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now()
);

create index learning_materials_class_subject_idx
  on public.learning_materials (class_subject_id);

create table public.message_threads (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  subject text,
  created_at timestamptz not null default now()
);

create table public.message_participants (
  thread_id uuid not null references public.message_threads (id) on delete cascade,
  person_id uuid not null references public.profiles (id) on delete cascade,
  school_id uuid not null references public.schools (id) on delete cascade,
  primary key (thread_id, person_id)
);

create index message_participants_person_idx
  on public.message_participants (person_id);

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  thread_id uuid not null references public.message_threads (id) on delete cascade,
  sender_id uuid not null references public.profiles (id) on delete cascade,
  body text not null,
  created_at timestamptz not null default now()
);

create index messages_thread_idx on public.messages (thread_id);

-- Append-only audit trail for sensitive access and changes.
create table public.audit_log (
  id bigint generated always as identity primary key,
  school_id uuid references public.schools (id) on delete set null,
  actor_id uuid references public.profiles (id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index audit_log_school_idx on public.audit_log (school_id);
create index audit_log_entity_idx on public.audit_log (entity_type, entity_id);

-- Keep profiles.updated_at fresh.
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_set_updated_at
before update on public.profiles
for each row
execute function public.set_updated_at();
