-- Student onboarding: study habits, focus subjects and goals.
--
-- Asked once when a student first signs in, per school year, and editable later:
--   1. Which subjects they most want to improve (focus subjects, at most 3)
--   2. A target percentage for each subject
--   3. How long they usually study in one go
--   4. How they study (several)
--   5. When they study (several)
--
-- Who can see it: the student, their teachers, their parents and school admins.
-- Who can change it: only the student.

create type public.study_session_length as enum ('minutes_15', 'minutes_30', 'minutes_45', 'minutes_60_plus');
create type public.study_method as enum (
  'pen_and_paper', 'videos', 'ai_chat', 'past_papers', 'flashcards', 'study_group'
);
create type public.study_time as enum ('afternoon', 'evening', 'late_night', 'weekends');

-- True when an array has no repeated values. Used in check constraints.
create function private.has_no_duplicates(p_values anyarray)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select count(*) = count(distinct v) from unnest(p_values) as v
$$;

-- Check constraints run as whoever writes the row, so writers need to run it.
revoke execute on function private.has_no_duplicates(anyarray) from public;
grant execute on function private.has_no_duplicates(anyarray) to authenticated, service_role;

-- ---------------------------------------------------------------------------------
-- 1. Study habits: one row per student per school year
-- ---------------------------------------------------------------------------------

create table public.student_study_profiles (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null,
  academic_year_id uuid not null,
  student_profile_id uuid not null,
  student_role public.membership_role not null default 'student' check (student_role = 'student'),
  session_length public.study_session_length,
  study_methods public.study_method[] not null default '{}'
    check (private.has_no_duplicates(study_methods)),
  study_times public.study_time[] not null default '{}'
    check (private.has_no_duplicates(study_times)),
  -- Set when the student finishes onboarding; the app shows onboarding until then.
  onboarding_completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (school_id, academic_year_id, student_profile_id),
  foreign key (academic_year_id, school_id)
    references public.academic_years (id, school_id) on delete restrict,
  foreign key (school_id, student_profile_id, student_role)
    references public.school_memberships (school_id, profile_id, role) on delete restrict
);

comment on table public.student_study_profiles is
  'A student''s study habits for one school year, from onboarding. Visible to the student, their teachers, parents and school admins.';

create index student_study_profiles_academic_year_id_school_id_idx
  on public.student_study_profiles (academic_year_id, school_id);
create index student_study_profiles_student_idx
  on public.student_study_profiles (school_id, student_profile_id, student_role);

-- ---------------------------------------------------------------------------------
-- 2. Goals: one row per student, school year and subject
-- ---------------------------------------------------------------------------------

create table public.student_subject_goals (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null,
  academic_year_id uuid not null,
  student_profile_id uuid not null,
  student_role public.membership_role not null default 'student' check (student_role = 'student'),
  subject_id uuid not null,
  -- One of the (at most 3) subjects the student most wants to improve.
  is_focus boolean not null default false,
  -- The mark the student is aiming for. A number, so progress can be tracked.
  target_percent smallint check (target_percent between 1 and 100),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (school_id, academic_year_id, student_profile_id, subject_id),
  foreign key (academic_year_id, school_id)
    references public.academic_years (id, school_id) on delete restrict,
  foreign key (school_id, student_profile_id, student_role)
    references public.school_memberships (school_id, profile_id, role) on delete restrict,
  foreign key (subject_id, school_id)
    references public.subjects (id, school_id) on delete restrict
);

comment on table public.student_subject_goals is
  'A student''s target and focus flag for a subject in one school year. Changes are kept in the audit log.';

create index student_subject_goals_academic_year_id_school_id_idx
  on public.student_subject_goals (academic_year_id, school_id);
create index student_subject_goals_student_idx
  on public.student_subject_goals (school_id, student_profile_id, student_role);
create index student_subject_goals_subject_id_school_id_idx
  on public.student_subject_goals (subject_id, school_id);

-- At most 3 focus subjects per student per year.
create function private.limit_focus_subjects()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.is_focus then
    -- Serialise changes to one student's goals, so two at once can't both pass.
    perform pg_advisory_xact_lock(
      hashtextextended(new.school_id::text || new.academic_year_id::text || new.student_profile_id::text, 0)
    );
    if (
      select count(*)
      from public.student_subject_goals g
      where g.school_id = new.school_id
        and g.academic_year_id = new.academic_year_id
        and g.student_profile_id = new.student_profile_id
        and g.is_focus
        -- Not this row: on update it has the same id; on an upsert (insert ... on
        -- conflict do update) this trigger runs before the conflict is found and
        -- new.id is a fresh one, so match the existing row by its subject too.
        and g.id <> new.id
        and g.subject_id <> new.subject_id
    ) >= 3 then
      raise exception 'A student can have at most 3 focus subjects'
        using errcode = '23514';
    end if;
  end if;
  return new;
end;
$$;

revoke execute on function private.limit_focus_subjects() from public;

create trigger student_subject_goals_limit_focus
  before insert or update of is_focus, school_id, academic_year_id, student_profile_id
  on public.student_subject_goals
  for each row execute function private.limit_focus_subjects();

create trigger student_study_profiles_set_updated_at before update on public.student_study_profiles
  for each row execute function private.set_updated_at();
create trigger student_subject_goals_set_updated_at before update on public.student_subject_goals
  for each row execute function private.set_updated_at();

-- Goal changes are kept, so progress against earlier targets can be shown.
create trigger student_subject_goals_audit after insert or update or delete on public.student_subject_goals
  for each row execute function private.audit_row_change();

-- ---------------------------------------------------------------------------------
-- 3. Access helpers
-- ---------------------------------------------------------------------------------

-- Is the signed-in person this student, as an active student at this school?
create function private.is_this_student(p_school_id uuid, p_student_profile_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_student_profile_id = (select private.current_profile_id())
     and private.has_role(p_school_id, 'student')
$$;

-- Can the signed-in person see this student's study habits and goals? The student,
-- their teachers, their parents, and admins of the school.
create function private.can_view_student_study(p_school_id uuid, p_student_profile_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.is_this_student(p_school_id, p_student_profile_id)
      or private.is_school_admin(p_school_id)
      or private.teaches_student(p_student_profile_id)
      or private.is_parent_of(p_student_profile_id)
$$;

-- Does the signed-in student take this subject this school year (are they in a class
-- that has it)?
create function private.takes_subject(p_academic_year_id uuid, p_subject_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.enrolments e
    join public.classes c on c.id = e.class_id
    join public.class_subjects cs on cs.class_id = c.id
    where e.student_profile_id = (select private.current_profile_id())
      and c.academic_year_id = p_academic_year_id
      and cs.subject_id = p_subject_id
      and private.has_role(e.school_id, 'student')
  )
$$;

-- Policies run as the signed-in user, so they need to be able to call these helpers.
revoke execute on function
  private.is_this_student(uuid, uuid),
  private.can_view_student_study(uuid, uuid),
  private.takes_subject(uuid, uuid)
from public;
grant execute on function
  private.is_this_student(uuid, uuid),
  private.can_view_student_study(uuid, uuid),
  private.takes_subject(uuid, uuid)
to authenticated;

-- ---------------------------------------------------------------------------------
-- 4. Row-level security
-- ---------------------------------------------------------------------------------

select private.expose_table('public.student_study_profiles', 'select, insert, update, delete');
select private.expose_table('public.student_subject_goals', 'select, insert, update, delete');

create policy "Visible to the student, their teachers, parents and admins"
  on public.student_study_profiles for select to authenticated
  using (private.can_view_student_study(school_id, student_profile_id));

create policy "Students can add their own study habits"
  on public.student_study_profiles for insert to authenticated
  with check (private.is_this_student(school_id, student_profile_id));

create policy "Students can change their own study habits"
  on public.student_study_profiles for update to authenticated
  using (private.is_this_student(school_id, student_profile_id))
  with check (private.is_this_student(school_id, student_profile_id));

create policy "Students can remove their own study habits"
  on public.student_study_profiles for delete to authenticated
  using (private.is_this_student(school_id, student_profile_id));

create policy "Visible to the student, their teachers, parents and admins"
  on public.student_subject_goals for select to authenticated
  using (private.can_view_student_study(school_id, student_profile_id));

create policy "Students can set goals for subjects they take"
  on public.student_subject_goals for insert to authenticated
  with check (
    private.is_this_student(school_id, student_profile_id)
    and private.takes_subject(academic_year_id, subject_id)
  );

create policy "Students can change goals for subjects they take"
  on public.student_subject_goals for update to authenticated
  using (private.is_this_student(school_id, student_profile_id))
  with check (
    private.is_this_student(school_id, student_profile_id)
    and private.takes_subject(academic_year_id, subject_id)
  );

create policy "Students can remove their own goals"
  on public.student_subject_goals for delete to authenticated
  using (private.is_this_student(school_id, student_profile_id));
