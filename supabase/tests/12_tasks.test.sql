-- Tasks: a teacher sets work for classes they teach, with notes, a due date and files;
-- students in those classes see it and tick it off; a student's own reminders are
-- private to them; classmates never see each other's progress.
--
-- Seed: Sizwe (02) teaches 10B Maths (class subject 70..01). Priya (03) teaches 10B
-- English (70..02) and 10C English (70..03). Amara (04) and Liam (05) are in 10B, Zoe
-- (06) in 10C. Ngozi (07) is Amara's parent. Grace (11) is Other College's admin.

begin;
create extension if not exists pgtap with schema extensions;

select plan(32);

create function pg_temp.as_user(p_user text)
returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
end;
$$;

-- ---------------------------------------------------------------------------------
-- A teacher sets a task
-- ---------------------------------------------------------------------------------

select pg_temp.as_user('30000000-0000-4000-8000-000000000002');
set local role authenticated;

select lives_ok(
  $$ insert into public.tasks (id, school_id, academic_year_id, kind, title, notes, due_at, subject_id, created_by)
     values ('90000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001',
             '20000000-0000-4000-8000-000000000001', 'assigned', 'Exercise 4.2: quadratic equations',
             'Questions 1-8. Show your working.', '2026-11-12 15:00+02', '50000000-0000-4000-8000-000000000001',
             '40000000-0000-4000-8000-000000000002') $$,
  'A teacher sets a task with notes and a due date'
);
select lives_ok(
  $$ insert into public.task_classes (task_id, school_id, class_subject_id)
     values ('90000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001',
             '70000000-0000-4000-8000-000000000001') $$,
  'and sends it to a class they teach (10B Maths)'
);
select throws_ok(
  $$ insert into public.task_classes (task_id, school_id, class_subject_id)
     values ('90000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001',
             '70000000-0000-4000-8000-000000000003') $$,
  '42501', null,
  'but not to a class they don''t teach (10C English)'
);
select lives_ok(
  $$ insert into public.task_attachments (task_id, school_id, storage_path, file_name, size_bytes, content_type, uploaded_by)
     values ('90000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001',
             '10000000-0000-4000-8000-000000000001/90000000-0000-4000-8000-000000000001/worksheet.pdf',
             'worksheet.pdf', 2400000, 'application/pdf', '40000000-0000-4000-8000-000000000002') $$,
  'The teacher attaches a file to their task'
);
select throws_ok(
  $$ insert into public.task_attachments (task_id, school_id, storage_path, file_name, size_bytes, uploaded_by)
     values ('90000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001',
             '10000000-0000-4000-8000-000000000001/90000000-0000-4000-8000-000000000001/huge.mp4',
             'huge.mp4', 314572801, '40000000-0000-4000-8000-000000000002') $$,
  '23514', null,
  'Files over 300 MB are refused'
);
select lives_ok(
  $$ insert into storage.objects (bucket_id, name, owner)
     values ('task-files', '10000000-0000-4000-8000-000000000001/90000000-0000-4000-8000-000000000001/worksheet.pdf',
             '30000000-0000-4000-8000-000000000002') $$,
  'The teacher uploads the file to the task''s storage folder'
);
select throws_ok(
  $$ insert into storage.objects (bucket_id, name, owner)
     values ('task-files', '10000000-0000-4000-8000-000000000002/90000000-0000-4000-8000-000000000001/sneaky.pdf',
             '30000000-0000-4000-8000-000000000002') $$,
  '42501', null,
  'but not into another school''s folder'
);
select throws_ok(
  $$ insert into public.tasks (school_id, academic_year_id, kind, title, due_at, created_by)
     values ('10000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001', 'assigned',
             'No due date', null, '40000000-0000-4000-8000-000000000002') $$,
  '23514', null,
  'A task a teacher sets must have a due date'
);
reset role;

-- Another teacher can't add a class to Sizwe's task, even one they teach.
select pg_temp.as_user('30000000-0000-4000-8000-000000000003');
set local role authenticated;
select throws_ok(
  $$ insert into public.task_classes (task_id, school_id, class_subject_id)
     values ('90000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001',
             '70000000-0000-4000-8000-000000000002') $$,
  '42501', null,
  'Another teacher cannot send someone else''s task to their class'
);
select results_eq(
  $$ with u as (update public.tasks set title = 'Hijacked' where id = '90000000-0000-4000-8000-000000000001' returning 1)
     select count(*)::int from u $$,
  $$ values (0) $$,
  'nor change it'
);
reset role;

-- ---------------------------------------------------------------------------------
-- Students see it and tick it off
-- ---------------------------------------------------------------------------------

select pg_temp.as_user('30000000-0000-4000-8000-000000000004');
set local role authenticated;
select results_eq(
  $$ select t.title, t.notes, (select count(*)::int from public.task_attachments a where a.task_id = t.id)
     from public.tasks t $$,
  $$ values ('Exercise 4.2: quadratic equations'::text, 'Questions 1-8. Show your working.'::text, 1) $$,
  'A student in the class sees the task, its notes and its file'
);
select is(
  (select count(*)::int from storage.objects where bucket_id = 'task-files'),
  1,
  'and can download the file'
);
select lives_ok(
  $$ insert into public.task_completions (task_id, school_id, student_profile_id)
     values ('90000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001',
             '40000000-0000-4000-8000-000000000004') $$,
  'She ticks it off'
);
select throws_ok(
  $$ insert into public.task_completions (task_id, school_id, student_profile_id)
     values ('90000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001',
             '40000000-0000-4000-8000-000000000005') $$,
  '42501', null,
  'She cannot tick it off for a classmate'
);

-- Her own reminder.
select lives_ok(
  $$ insert into public.tasks (id, school_id, academic_year_id, kind, title, due_at, created_by)
     values ('90000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000001',
             '20000000-0000-4000-8000-000000000001', 'personal', 'Revise trig identities', '2026-11-08 18:00+02',
             '40000000-0000-4000-8000-000000000004') $$,
  'A student adds her own reminder with a due date'
);
select lives_ok(
  $$ insert into public.tasks (school_id, academic_year_id, kind, title, created_by)
     values ('10000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001', 'personal',
             'Buy a new calculator', '40000000-0000-4000-8000-000000000004') $$,
  'or without one'
);
select lives_ok(
  $$ insert into public.task_completions (task_id, school_id, student_profile_id)
     values ('90000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000001',
             '40000000-0000-4000-8000-000000000004') $$,
  'and ticks her reminder off'
);
select throws_ok(
  $$ insert into public.tasks (school_id, academic_year_id, kind, title, due_at, created_by)
     values ('10000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001', 'assigned',
             'Homework for everyone', now(), '40000000-0000-4000-8000-000000000004') $$,
  '42501', null,
  'A student cannot set tasks for a class'
);
reset role;

-- ---------------------------------------------------------------------------------
-- Who sees what
-- ---------------------------------------------------------------------------------

create function pg_temp.sees(p_user text)
returns table (tasks int, personal int, completions int, files int)
language plpgsql as $$
begin
  perform pg_temp.as_user(p_user);
  set local role authenticated;
  return query select
    (select count(*)::int from public.tasks),
    (select count(*)::int from public.tasks where kind = 'personal'),
    (select count(*)::int from public.task_completions),
    (select count(*)::int from storage.objects where bucket_id = 'task-files');
  reset role;
end;
$$;

select results_eq($$ select * from pg_temp.sees('30000000-0000-4000-8000-000000000004') $$,
  $$ values (3, 2, 2, 1) $$, 'Amara sees the class task, her 2 reminders, her 2 ticks and the file');
select results_eq($$ select * from pg_temp.sees('30000000-0000-4000-8000-000000000005') $$,
  $$ values (1, 0, 0, 1) $$, 'Liam (same class) sees the task and file, but not Amara''s reminders or ticks');
select results_eq($$ select * from pg_temp.sees('30000000-0000-4000-8000-000000000002') $$,
  $$ values (1, 0, 1, 1) $$, 'Sizwe (her teacher) sees the task and Amara''s tick, but not her reminders');
select results_eq($$ select * from pg_temp.sees('30000000-0000-4000-8000-000000000007') $$,
  $$ values (1, 0, 1, 1) $$, 'Ngozi (her parent) sees the class task and Amara''s tick on it, but nothing of her reminders');
select results_eq($$ select * from pg_temp.sees('30000000-0000-4000-8000-000000000006') $$,
  $$ values (0, 0, 0, 0) $$, 'Zoe (another class) sees nothing');
select results_eq($$ select * from pg_temp.sees('30000000-0000-4000-8000-000000000011') $$,
  $$ values (0, 0, 0, 0) $$, 'Another school''s admin sees nothing');

-- A task's classes stay in its subject: it can't be relabelled as another subject.
select pg_temp.as_user('30000000-0000-4000-8000-000000000002');
set local role authenticated;
select throws_ok(
  $$ update public.tasks set subject_id = '50000000-0000-4000-8000-000000000002'
     where id = '90000000-0000-4000-8000-000000000001' $$,
  '23514', null,
  'A Maths task sent to 10B Maths cannot be relabelled as English'
);
reset role;
-- Priya teaches 10B English; her English task cannot go to a Maths class she doesn't
-- teach, nor to an English class while labelled for another subject.
select pg_temp.as_user('30000000-0000-4000-8000-000000000003');
set local role authenticated;
insert into public.tasks (id, school_id, academic_year_id, kind, title, due_at, subject_id, created_by)
values ('90000000-0000-4000-8000-000000000009', '10000000-0000-4000-8000-000000000001',
        '20000000-0000-4000-8000-000000000001', 'assigned', 'Essay plan', '2026-11-20 15:00+02',
        '50000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000003');
select throws_ok(
  $$ insert into public.task_classes (task_id, school_id, class_subject_id)
     values ('90000000-0000-4000-8000-000000000009', '10000000-0000-4000-8000-000000000001',
             '70000000-0000-4000-8000-000000000002') $$,
  '23514', null,
  'A task labelled Maths cannot go to an English class'
);
reset role;

-- A teacher who has left can't change their tasks any more.
update public.school_memberships set status = 'inactive'
where profile_id = '40000000-0000-4000-8000-000000000002' and role = 'teacher';
select pg_temp.as_user('30000000-0000-4000-8000-000000000002');
set local role authenticated;
update public.tasks set title = 'Changed after leaving' where id = '90000000-0000-4000-8000-000000000001';
select throws_ok(
  $$ insert into public.task_attachments (task_id, school_id, storage_path, file_name, size_bytes, uploaded_by)
     values ('90000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001',
             '10000000-0000-4000-8000-000000000001/90000000-0000-4000-8000-000000000001/late.pdf',
             'late.pdf', 10, '40000000-0000-4000-8000-000000000002') $$,
  '42501', null,
  'A teacher who has left cannot attach files'
);
reset role;
select is(
  (select title from public.tasks where id = '90000000-0000-4000-8000-000000000001'),
  'Exercise 4.2: quadratic equations',
  'nor change their task'
);
update public.school_memberships set status = 'active'
where profile_id = '40000000-0000-4000-8000-000000000002' and role = 'teacher';

-- Deleting a task removes its classes, files' rows and ticks with it.
select pg_temp.as_user('30000000-0000-4000-8000-000000000002');
set local role authenticated;
select lives_ok(
  $$ delete from public.tasks where id = '90000000-0000-4000-8000-000000000001' $$,
  'The teacher deletes their task'
);
reset role;
select ok(
  not exists (select 1 from public.task_classes where task_id = '90000000-0000-4000-8000-000000000001')
  and not exists (select 1 from public.task_attachments where task_id = '90000000-0000-4000-8000-000000000001')
  and not exists (select 1 from public.task_completions where task_id = '90000000-0000-4000-8000-000000000001'),
  'and its classes, attachments and ticks go with it'
);
select set_eq(
  $$ select path from private.task_file_cleanup $$,
  $$ values ('10000000-0000-4000-8000-000000000001/90000000-0000-4000-8000-000000000001/'),
            ('10000000-0000-4000-8000-000000000001/90000000-0000-4000-8000-000000000001/worksheet.pdf') $$,
  'Its files are queued for removal from storage'
);
select ok(
  not has_table_privilege('authenticated', 'private.task_file_cleanup', 'SELECT')
  and not has_table_privilege('authenticated', 'private.task_file_cleanup', 'DELETE'),
  'Nobody signed in can read or clear the clean-up queue'
);

select * from finish();
rollback;
