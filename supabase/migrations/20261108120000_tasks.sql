-- Tasks: work a teacher sets for their classes, and a student's own to-dos.
--
--   assigned  A teacher sets it for one or more of the classes they teach: a title,
--             notes (instructions), a due date and attached files. Students in those
--             classes see it and tick it off; the teacher sees who has finished.
--   personal  A student's own reminder: a title and an optional due date, like Apple
--             Reminders. Private to that student: no teacher or parent sees it.
--
-- Attached files live in the private storage bucket "task-files", at
-- <school id>/<task id>/<file>. Up to 300 MB each, in the file types schools use.

create type public.task_kind as enum ('assigned', 'personal');

create table public.tasks (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete restrict,
  academic_year_id uuid not null,
  kind public.task_kind not null,
  title text not null check (length(trim(title)) between 1 and 200),
  -- The teacher's instructions, or a student's own note.
  notes text check (notes is null or length(notes) <= 20000),
  due_at timestamptz,
  -- The subject an assigned task is for (the classes it was sent to share it).
  subject_id uuid,
  -- The teacher who set it, or the student whose reminder it is.
  created_by uuid not null references public.profiles (id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (kind = 'personal' or due_at is not null),
  check (kind = 'assigned' or subject_id is null),
  unique (id, school_id),
  foreign key (academic_year_id, school_id)
    references public.academic_years (id, school_id) on delete restrict,
  foreign key (subject_id, school_id)
    references public.subjects (id, school_id) on delete restrict
);

comment on table public.tasks is
  'Work a teacher sets for their classes (assigned), or a student''s own reminder (personal, private to them).';

-- The classes (each a class and subject) an assigned task was sent to.
create table public.task_classes (
  task_id uuid not null,
  school_id uuid not null,
  class_subject_id uuid not null,
  created_at timestamptz not null default now(),
  primary key (task_id, class_subject_id),
  foreign key (task_id, school_id) references public.tasks (id, school_id) on delete cascade,
  foreign key (class_subject_id, school_id)
    references public.class_subjects (id, school_id) on delete restrict
);

comment on table public.task_classes is 'Which classes an assigned task was sent to.';

-- Files attached to a task. The file itself is in storage; this row names it.
create table public.task_attachments (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null,
  school_id uuid not null,
  storage_path text not null unique,
  file_name text not null check (length(trim(file_name)) between 1 and 255),
  size_bytes bigint not null check (size_bytes between 1 and 314572800),
  content_type text,
  uploaded_by uuid not null references public.profiles (id) on delete restrict,
  created_at timestamptz not null default now(),
  -- The file sits under its own school and task.
  check (storage_path like school_id::text || '/' || task_id::text || '/%'),
  foreign key (task_id, school_id) references public.tasks (id, school_id) on delete cascade
);

comment on table public.task_attachments is
  'Files attached to a task, stored in the private "task-files" bucket under <school>/<task>/.';

-- Who has finished a task. One row per student per task; removed when unticked.
create table public.task_completions (
  task_id uuid not null,
  school_id uuid not null,
  student_profile_id uuid not null,
  student_role public.membership_role not null default 'student' check (student_role = 'student'),
  completed_at timestamptz not null default now(),
  primary key (task_id, student_profile_id),
  foreign key (task_id, school_id) references public.tasks (id, school_id) on delete cascade,
  foreign key (school_id, student_profile_id, student_role)
    references public.school_memberships (school_id, profile_id, role) on delete restrict
);

comment on table public.task_completions is 'Which students have ticked off which tasks.';

create index tasks_school_id_idx on public.tasks (school_id);
create index tasks_academic_year_id_school_id_idx on public.tasks (academic_year_id, school_id);
create index tasks_subject_id_school_id_idx on public.tasks (subject_id, school_id);
create index tasks_created_by_idx on public.tasks (created_by);
create index task_classes_task_id_school_id_idx on public.task_classes (task_id, school_id);
create index task_classes_class_subject_id_school_id_idx on public.task_classes (class_subject_id, school_id);
create index task_attachments_task_id_school_id_idx on public.task_attachments (task_id, school_id);
create index task_attachments_uploaded_by_idx on public.task_attachments (uploaded_by);
create index task_completions_task_id_school_id_idx on public.task_completions (task_id, school_id);
create index task_completions_student_idx
  on public.task_completions (school_id, student_profile_id, student_role);

create trigger tasks_set_updated_at before update on public.tasks
  for each row execute function private.set_updated_at();
create trigger tasks_audit after insert or update or delete on public.tasks
  for each row execute function private.audit_row_change();

-- ---------------------------------------------------------------------------------
-- Access helpers
-- ---------------------------------------------------------------------------------

-- Does the signed-in person (as an active teacher) teach this class and subject?
create function private.teaches_class_subject(p_class_subject_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.teaching_allocations ta
    join public.school_memberships m
      on m.school_id = ta.school_id
     and m.profile_id = ta.teacher_profile_id
     and m.role = 'teacher'
     and m.status = 'active'
    where ta.class_subject_id = p_class_subject_id
      and ta.teacher_profile_id = (select private.current_profile_id())
  )
$$;

-- Did the signed-in person create this task?
create function private.is_task_creator(p_task_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.tasks t
    where t.id = p_task_id and t.created_by = (select private.current_profile_id())
  )
$$;

-- Can the signed-in person see this task? Its creator always; a personal task no one
-- else; an assigned task anyone who can see one of its classes (the teachers, the
-- students in it, their parents) and the school's admins.
create function private.can_view_task(p_task_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.tasks t
    where t.id = p_task_id
      and (
        t.created_by = (select private.current_profile_id())
        or (
          t.kind = 'assigned'
          and (
            private.is_school_admin(t.school_id)
            or exists (
              select 1
              from public.task_classes tc
              join public.class_subjects cs on cs.id = tc.class_subject_id
              where tc.task_id = t.id and private.can_view_class(cs.class_id)
            )
          )
        )
      )
  )
$$;

-- Can the signed-in student tick this task off? Their own reminder, or an assigned
-- task sent to a class they're in.
create function private.can_complete_task(p_task_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.tasks t
    where t.id = p_task_id
      and (
        (t.kind = 'personal' and t.created_by = (select private.current_profile_id()))
        or (
          t.kind = 'assigned'
          and exists (
            select 1
            from public.task_classes tc
            join public.class_subjects cs on cs.id = tc.class_subject_id
            where tc.task_id = t.id and private.is_enrolled_in(cs.class_id)
          )
        )
      )
  )
$$;

-- The task a storage path belongs to: <school id>/<task id>/<file>. Null for any
-- other shape, so a malformed name can never match a task.
create function private.task_id_from_path(p_name text)
returns uuid
language sql
immutable
set search_path = ''
as $$
  select case
    when p_name ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}/[^/]+$'
    then split_part(p_name, '/', 2)::uuid
  end
$$;

-- May the signed-in person upload or remove this file? Only the task's creator, and
-- only under the task's own school folder.
create function private.can_manage_task_file(p_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.tasks t
    where t.id = private.task_id_from_path(p_name)
      and split_part(p_name, '/', 1) = t.school_id::text
      and t.created_by = (select private.current_profile_id())
  )
$$;

revoke execute on function
  private.teaches_class_subject(uuid),
  private.is_task_creator(uuid),
  private.can_view_task(uuid),
  private.can_complete_task(uuid),
  private.task_id_from_path(text),
  private.can_manage_task_file(text)
from public;
grant execute on function
  private.teaches_class_subject(uuid),
  private.is_task_creator(uuid),
  private.can_view_task(uuid),
  private.can_complete_task(uuid),
  private.task_id_from_path(text),
  private.can_manage_task_file(text)
to authenticated;

-- ---------------------------------------------------------------------------------
-- Row-level security
-- ---------------------------------------------------------------------------------

select private.expose_table('public.tasks', 'select, insert, delete');
select private.expose_table('public.task_classes', 'select, insert, delete');
select private.expose_table('public.task_attachments', 'select, insert, delete');
select private.expose_table('public.task_completions', 'select, insert, delete');

-- Only what a task says can change; never whose it is or what kind.
grant update (title, notes, due_at, subject_id) on public.tasks to authenticated;

-- The creator check is inline so a task is visible to its creator straight after
-- insert (a helper querying the table would not see the new row yet).
create policy "Creators, and for assigned tasks the class's people and admins, can see tasks"
  on public.tasks for select to authenticated
  using (created_by = (select private.current_profile_id()) or private.can_view_task(id));

create policy "Teachers set tasks; students add their own reminders"
  on public.tasks for insert to authenticated
  with check (
    created_by = (select private.current_profile_id())
    and (
      (kind = 'assigned' and private.has_role(school_id, 'teacher'))
      or (kind = 'personal' and private.has_role(school_id, 'student'))
    )
  );

create policy "Creators can change their tasks"
  on public.tasks for update to authenticated
  using (created_by = (select private.current_profile_id()))
  with check (created_by = (select private.current_profile_id()));

create policy "Creators can remove their tasks"
  on public.tasks for delete to authenticated
  using (created_by = (select private.current_profile_id()));

create policy "Visible with the task"
  on public.task_classes for select to authenticated
  using (private.can_view_task(task_id));

create policy "A teacher sends their own task to classes they teach"
  on public.task_classes for insert to authenticated
  with check (
    private.is_task_creator(task_id)
    and private.teaches_class_subject(class_subject_id)
    and exists (select 1 from public.tasks t where t.id = task_id and t.kind = 'assigned')
  );

create policy "A teacher can take their task back from a class"
  on public.task_classes for delete to authenticated
  using (private.is_task_creator(task_id));

create policy "Visible with the task"
  on public.task_attachments for select to authenticated
  using (private.can_view_task(task_id));

create policy "The task's creator attaches files"
  on public.task_attachments for insert to authenticated
  with check (
    private.is_task_creator(task_id)
    and uploaded_by = (select private.current_profile_id())
  );

create policy "The task's creator removes files"
  on public.task_attachments for delete to authenticated
  using (private.is_task_creator(task_id));

-- A student sees their own ticks. Their parents, teachers and admins see their ticks
-- on tasks they can see themselves, so a private reminder stays private. Classmates
-- never see each other's.
create policy "The student, their parents, their teachers and admins see completions"
  on public.task_completions for select to authenticated
  using (
    student_profile_id = (select private.current_profile_id())
    or (
      private.can_view_task(task_id)
      and (
        private.is_parent_of(student_profile_id)
        or private.teaches_student(student_profile_id)
        or private.is_school_admin(school_id)
      )
    )
  );

create policy "Students tick off tasks they have"
  on public.task_completions for insert to authenticated
  with check (
    student_profile_id = (select private.current_profile_id())
    and private.can_complete_task(task_id)
  );

create policy "Students untick their own tasks"
  on public.task_completions for delete to authenticated
  using (student_profile_id = (select private.current_profile_id()));

-- ---------------------------------------------------------------------------------
-- File storage
-- ---------------------------------------------------------------------------------

-- 300 MB each. The project's global upload limit (Storage settings) must be at least
-- this for it to take effect.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'task-files', 'task-files', false, 314572800,
  array[
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-powerpoint',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.oasis.opendocument.text',
    'application/vnd.oasis.opendocument.presentation',
    'application/vnd.oasis.opendocument.spreadsheet',
    'application/rtf',
    'text/plain',
    'text/csv',
    'image/*',
    'audio/*',
    'video/*',
    'application/zip',
    'application/x-zip-compressed'
  ]
)
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

create policy "Task files: anyone who can see the task can download"
  on storage.objects for select to authenticated
  using (bucket_id = 'task-files' and private.can_view_task(private.task_id_from_path(name)));

create policy "Task files: the task's creator uploads"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'task-files' and private.can_manage_task_file(name));

create policy "Task files: the task's creator replaces"
  on storage.objects for update to authenticated
  using (bucket_id = 'task-files' and private.can_manage_task_file(name))
  with check (bucket_id = 'task-files' and private.can_manage_task_file(name));

create policy "Task files: the task's creator removes"
  on storage.objects for delete to authenticated
  using (bucket_id = 'task-files' and private.can_manage_task_file(name));
