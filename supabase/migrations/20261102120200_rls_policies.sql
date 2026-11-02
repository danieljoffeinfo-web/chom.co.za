-- Row-level security: every school-scoped table checks membership (and role)
-- inside Postgres so web, mobile and future clients share one access model.

create or replace function public.is_school_member(p_school_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.school_memberships m
    where m.school_id = p_school_id
      and m.person_id = auth.uid()
  );
$$;

revoke all on function public.is_school_member(uuid) from public;
grant execute on function public.is_school_member(uuid) to authenticated;

create or replace function public.has_school_role(p_school_id uuid, p_roles public.app_role[])
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.school_memberships m
    where m.school_id = p_school_id
      and m.person_id = auth.uid()
      and m.role = any (p_roles)
  );
$$;

revoke all on function public.has_school_role(uuid, public.app_role[]) from public;
grant execute on function public.has_school_role(uuid, public.app_role[]) to authenticated;

create or replace function public.can_access_class_subject(p_class_subject_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.class_subjects cs
    where cs.id = p_class_subject_id
      and (
        public.has_school_role(cs.school_id, array['school_admin'::public.app_role])
        or cs.teacher_id = auth.uid()
        or exists (
          select 1
          from public.enrolments e
          where e.class_id = cs.class_id
            and e.student_id = auth.uid()
        )
        or exists (
          select 1
          from public.enrolments e
          join public.guardianships g
            on g.learner_id = e.student_id
           and g.school_id = e.school_id
          where e.class_id = cs.class_id
            and g.parent_id = auth.uid()
        )
      )
  );
$$;

revoke all on function public.can_access_class_subject(uuid) from public;
grant execute on function public.can_access_class_subject(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Enable RLS on every table that holds school or personal data.
-- ---------------------------------------------------------------------------

alter table public.schools enable row level security;
alter table public.profiles enable row level security;
alter table public.school_memberships enable row level security;
alter table public.classes enable row level security;
alter table public.subjects enable row level security;
alter table public.class_subjects enable row level security;
alter table public.enrolments enable row level security;
alter table public.guardianships enable row level security;
alter table public.tasks enable row level security;
alter table public.task_completions enable row level security;
alter table public.assignments enable row level security;
alter table public.submissions enable row level security;
alter table public.learning_materials enable row level security;
alter table public.message_threads enable row level security;
alter table public.message_participants enable row level security;
alter table public.messages enable row level security;
alter table public.audit_log enable row level security;

-- Schools: members can read their school. Creating and editing schools is done
-- with the service role (onboarding and Ednana sync), not from client JWTs —
-- otherwise the first admin could never be attached to a school that does not
-- exist yet.
create policy schools_select_member
  on public.schools for select to authenticated
  using (public.is_school_member(id));

-- Profiles: people read their own row and people they share a school with.
create policy profiles_select_self_or_school
  on public.profiles for select to authenticated
  using (
    id = auth.uid()
    or exists (
      select 1
      from public.school_memberships mine
      join public.school_memberships theirs
        on theirs.school_id = mine.school_id
      where mine.person_id = auth.uid()
        and theirs.person_id = profiles.id
    )
  );

create policy profiles_update_self
  on public.profiles for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

create policy profiles_insert_self
  on public.profiles for insert to authenticated
  with check (id = auth.uid());

-- Memberships
create policy memberships_select_school
  on public.school_memberships for select to authenticated
  using (public.is_school_member(school_id));

create policy memberships_write_admin
  on public.school_memberships for all to authenticated
  using (public.has_school_role(school_id, array['school_admin'::public.app_role]))
  with check (public.has_school_role(school_id, array['school_admin'::public.app_role]));

-- Classes / subjects / class_subjects
create policy classes_select_member
  on public.classes for select to authenticated
  using (public.is_school_member(school_id));

create policy classes_write_staff
  on public.classes for all to authenticated
  using (
    public.has_school_role(
      school_id,
      array['school_admin'::public.app_role, 'teacher'::public.app_role]
    )
  )
  with check (
    public.has_school_role(
      school_id,
      array['school_admin'::public.app_role, 'teacher'::public.app_role]
    )
  );

create policy subjects_select_member
  on public.subjects for select to authenticated
  using (public.is_school_member(school_id));

create policy subjects_write_staff
  on public.subjects for all to authenticated
  using (
    public.has_school_role(
      school_id,
      array['school_admin'::public.app_role, 'teacher'::public.app_role]
    )
  )
  with check (
    public.has_school_role(
      school_id,
      array['school_admin'::public.app_role, 'teacher'::public.app_role]
    )
  );

create policy class_subjects_select_access
  on public.class_subjects for select to authenticated
  using (public.can_access_class_subject(id));

create policy class_subjects_write_staff
  on public.class_subjects for all to authenticated
  using (
    public.has_school_role(school_id, array['school_admin'::public.app_role])
    or teacher_id = auth.uid()
  )
  with check (
    public.has_school_role(school_id, array['school_admin'::public.app_role])
    or teacher_id = auth.uid()
  );

-- Enrolments
create policy enrolments_select_related
  on public.enrolments for select to authenticated
  using (
    public.has_school_role(
      school_id,
      array['school_admin'::public.app_role, 'teacher'::public.app_role]
    )
    or student_id = auth.uid()
    or exists (
      select 1
      from public.guardianships g
      where g.school_id = enrolments.school_id
        and g.learner_id = enrolments.student_id
        and g.parent_id = auth.uid()
    )
  );

create policy enrolments_write_admin
  on public.enrolments for all to authenticated
  using (public.has_school_role(school_id, array['school_admin'::public.app_role]))
  with check (public.has_school_role(school_id, array['school_admin'::public.app_role]));

-- Guardianships: parent, learner, staff at the school.
create policy guardianships_select_related
  on public.guardianships for select to authenticated
  using (
    parent_id = auth.uid()
    or learner_id = auth.uid()
    or public.has_school_role(
      school_id,
      array['school_admin'::public.app_role, 'teacher'::public.app_role]
    )
  );

create policy guardianships_write_admin
  on public.guardianships for all to authenticated
  using (public.has_school_role(school_id, array['school_admin'::public.app_role]))
  with check (public.has_school_role(school_id, array['school_admin'::public.app_role]));

-- Tasks
create policy tasks_select_access
  on public.tasks for select to authenticated
  using (public.can_access_class_subject(class_subject_id));

create policy tasks_write_staff
  on public.tasks for all to authenticated
  using (
    public.has_school_role(school_id, array['school_admin'::public.app_role])
    or exists (
      select 1
      from public.class_subjects cs
      where cs.id = tasks.class_subject_id
        and cs.teacher_id = auth.uid()
    )
  )
  with check (
    public.has_school_role(school_id, array['school_admin'::public.app_role])
    or exists (
      select 1
      from public.class_subjects cs
      where cs.id = tasks.class_subject_id
        and cs.teacher_id = auth.uid()
    )
  );

-- Task completions: students manage their own; teachers/parents can read.
create policy task_completions_select_related
  on public.task_completions for select to authenticated
  using (
    student_id = auth.uid()
    or public.has_school_role(
      school_id,
      array['school_admin'::public.app_role, 'teacher'::public.app_role]
    )
    or exists (
      select 1
      from public.guardianships g
      where g.school_id = task_completions.school_id
        and g.learner_id = task_completions.student_id
        and g.parent_id = auth.uid()
    )
  );

create policy task_completions_insert_self
  on public.task_completions for insert to authenticated
  with check (
    student_id = auth.uid()
    and public.is_school_member(school_id)
  );

create policy task_completions_update_self
  on public.task_completions for update to authenticated
  using (student_id = auth.uid())
  with check (student_id = auth.uid());

create policy task_completions_delete_self
  on public.task_completions for delete to authenticated
  using (student_id = auth.uid());

-- Assignments: students/parents see published only; staff see all.
create policy assignments_select_access
  on public.assignments for select to authenticated
  using (
    public.can_access_class_subject(class_subject_id)
    and (
      status = 'published'
      or status = 'closed'
      or public.has_school_role(
        school_id,
        array['school_admin'::public.app_role, 'teacher'::public.app_role]
      )
    )
  );

create policy assignments_write_staff
  on public.assignments for all to authenticated
  using (
    public.has_school_role(school_id, array['school_admin'::public.app_role])
    or exists (
      select 1
      from public.class_subjects cs
      where cs.id = assignments.class_subject_id
        and cs.teacher_id = auth.uid()
    )
  )
  with check (
    public.has_school_role(school_id, array['school_admin'::public.app_role])
    or exists (
      select 1
      from public.class_subjects cs
      where cs.id = assignments.class_subject_id
        and cs.teacher_id = auth.uid()
    )
  );

-- Submissions
create policy submissions_select_related
  on public.submissions for select to authenticated
  using (
    student_id = auth.uid()
    or public.has_school_role(
      school_id,
      array['school_admin'::public.app_role, 'teacher'::public.app_role]
    )
    or exists (
      select 1
      from public.guardianships g
      where g.school_id = submissions.school_id
        and g.learner_id = submissions.student_id
        and g.parent_id = auth.uid()
    )
  );

create policy submissions_insert_self
  on public.submissions for insert to authenticated
  with check (
    student_id = auth.uid()
    and public.is_school_member(school_id)
  );

create policy submissions_update_related
  on public.submissions for update to authenticated
  using (
    student_id = auth.uid()
    or public.has_school_role(
      school_id,
      array['school_admin'::public.app_role, 'teacher'::public.app_role]
    )
  )
  with check (
    student_id = auth.uid()
    or public.has_school_role(
      school_id,
      array['school_admin'::public.app_role, 'teacher'::public.app_role]
    )
  );

-- Learning materials
create policy learning_materials_select_access
  on public.learning_materials for select to authenticated
  using (public.can_access_class_subject(class_subject_id));

create policy learning_materials_write_staff
  on public.learning_materials for all to authenticated
  using (
    public.has_school_role(school_id, array['school_admin'::public.app_role])
    or exists (
      select 1
      from public.class_subjects cs
      where cs.id = learning_materials.class_subject_id
        and cs.teacher_id = auth.uid()
    )
  )
  with check (
    public.has_school_role(school_id, array['school_admin'::public.app_role])
    or exists (
      select 1
      from public.class_subjects cs
      where cs.id = learning_materials.class_subject_id
        and cs.teacher_id = auth.uid()
    )
  );

-- Messaging: participants only; realtime should open only on the messages screen.
create policy message_threads_select_participant
  on public.message_threads for select to authenticated
  using (
    exists (
      select 1
      from public.message_participants mp
      where mp.thread_id = message_threads.id
        and mp.person_id = auth.uid()
    )
  );

create policy message_threads_insert_member
  on public.message_threads for insert to authenticated
  with check (public.is_school_member(school_id));

create policy message_participants_select_participant
  on public.message_participants for select to authenticated
  using (
    person_id = auth.uid()
    or exists (
      select 1
      from public.message_participants mine
      where mine.thread_id = message_participants.thread_id
        and mine.person_id = auth.uid()
    )
  );

create policy message_participants_insert_member
  on public.message_participants for insert to authenticated
  with check (
    public.is_school_member(school_id)
    and (
      person_id = auth.uid()
      or public.has_school_role(
        school_id,
        array['school_admin'::public.app_role, 'teacher'::public.app_role]
      )
    )
  );

create policy messages_select_participant
  on public.messages for select to authenticated
  using (
    exists (
      select 1
      from public.message_participants mp
      where mp.thread_id = messages.thread_id
        and mp.person_id = auth.uid()
    )
  );

create policy messages_insert_participant
  on public.messages for insert to authenticated
  with check (
    sender_id = auth.uid()
    and exists (
      select 1
      from public.message_participants mp
      where mp.thread_id = messages.thread_id
        and mp.person_id = auth.uid()
    )
  );

-- Audit log: school admins can read; inserts allowed for members; no update/delete.
create policy audit_log_select_admin
  on public.audit_log for select to authenticated
  using (
    school_id is not null
    and public.has_school_role(school_id, array['school_admin'::public.app_role])
  );

create policy audit_log_insert_member
  on public.audit_log for insert to authenticated
  with check (
    actor_id = auth.uid()
    and (
      school_id is null
      or public.is_school_member(school_id)
    )
  );
