'use server';

import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';

import { currentStaff } from '@/lib/current-staff';
import { createClient } from '@/lib/supabase/server';
import { MAX_FILE_BYTES, TASK_FILES_BUCKET } from '@/lib/task-files';

type Failed = { ok: false; error: string };

/** A real calendar day as YYYY-MM-DD (so 2026-02-30 is refused). */
function isCalendarDate(value: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const day = new Date(`${value}T00:00:00Z`);
  return !Number.isNaN(day.getTime()) && day.toISOString().slice(0, 10) === value;
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/**
 * Setting a task happens in three steps, so learners never see one half-made:
 *   1. createTask: the task itself (title, notes, due date), not yet sent to anyone.
 *   2. The browser uploads each file straight to storage, then addAttachment records it.
 *   3. publishTask: sends it to the chosen classes. Only now do learners see it.
 * Row-level security checks every step: only an active teacher, for their own task and
 * the classes they teach.
 */
export async function createTask(input: {
  title: string;
  notes: string;
  dueOn: string;
  dueTime: string;
  classSubjectIds: string[];
}): Promise<{ ok: true; taskId: string; schoolId: string } | Failed> {
  const staff = await currentStaff();
  if (!staff) return { ok: false, error: 'Please sign in again.' };

  const title = input.title.trim();
  const notes = input.notes.trim();
  if (!title || title.length > 200) {
    return { ok: false, error: 'Give the task a name (up to 200 characters).' };
  }
  if (notes.length > 20000) return { ok: false, error: 'The notes are too long.' };
  if (!isCalendarDate(input.dueOn) || !/^([01]\d|2[0-3]):[0-5]\d$/.test(input.dueTime)) {
    return { ok: false, error: 'Choose a due date and time.' };
  }
  const mine = new Set(staff.classes.map((c) => c.classSubjectId));
  const classIds = [...new Set(input.classSubjectIds)];
  if (!classIds.length) return { ok: false, error: 'Choose at least one class.' };
  if (!classIds.every((id) => mine.has(id))) {
    return { ok: false, error: 'You can only set work for classes you teach.' };
  }

  const supabase = await createClient();
  const [{ data: classSubjects }, { data: year }] = await Promise.all([
    supabase.from('class_subjects').select('id, subject_id').in('id', classIds),
    supabase
      .from('academic_years')
      .select('id')
      .eq('school_id', staff.schoolId)
      .eq('is_current', true)
      .maybeSingle(),
  ]);
  const subjects = new Set((classSubjects ?? []).map((c) => c.subject_id));
  if (subjects.size !== 1 || (classSubjects ?? []).length !== classIds.length) {
    return { ok: false, error: 'A task is for one subject: choose classes of the same subject.' };
  }
  if (!year) return { ok: false, error: 'Your school has no current year set up yet.' };

  const { data: task, error } = await supabase
    .from('tasks')
    .insert({
      school_id: staff.schoolId,
      academic_year_id: year.id,
      kind: 'assigned',
      title,
      notes: notes || null,
      // South Africa has no daylight saving: always +02:00.
      due_at: `${input.dueOn}T${input.dueTime}:00+02:00`,
      subject_id: [...subjects][0] ?? null,
      created_by: staff.profileId,
    })
    .select('id')
    .single();
  if (error || !task) return { ok: false, error: 'We couldn’t save the task. Please try again.' };
  return { ok: true, taskId: task.id, schoolId: staff.schoolId };
}

/** Records a file the browser has just uploaded to the task's folder. */
export async function addAttachment(input: {
  taskId: string;
  path: string;
  name: string;
  size: number;
  type: string;
}): Promise<{ ok: true } | Failed> {
  const staff = await currentStaff();
  if (!staff) return { ok: false, error: 'Please sign in again.' };
  if (
    !UUID.test(input.taskId) ||
    !input.path.startsWith(`${staff.schoolId}/${input.taskId}/`) ||
    input.size < 1 ||
    input.size > MAX_FILE_BYTES
  ) {
    return { ok: false, error: 'That file couldn’t be attached.' };
  }
  const supabase = await createClient();
  const { error } = await supabase.from('task_attachments').insert({
    task_id: input.taskId,
    school_id: staff.schoolId,
    storage_path: input.path,
    file_name: input.name.slice(0, 255) || 'file',
    size_bytes: input.size,
    content_type: input.type || null,
    uploaded_by: staff.profileId,
  });
  if (error) return { ok: false, error: 'That file couldn’t be attached.' };
  return { ok: true };
}

/** Sends the task to its classes: from now on those learners see it. */
export async function publishTask(input: {
  taskId: string;
  classSubjectIds: string[];
}): Promise<{ ok: true } | Failed> {
  const staff = await currentStaff();
  if (!staff) return { ok: false, error: 'Please sign in again.' };
  if (!UUID.test(input.taskId)) return { ok: false, error: 'That task wasn’t found.' };

  const classIds = [...new Set(input.classSubjectIds)];
  const mine = new Set(staff.classes.map((c) => c.classSubjectId));
  if (!classIds.length || !classIds.every((id) => mine.has(id))) {
    return { ok: false, error: 'You can only set work for classes you teach.' };
  }

  // The task's own subject decides which classes it can go to.
  const supabase = await createClient();
  const [{ data: task }, { data: classSubjects }] = await Promise.all([
    supabase
      .from('tasks')
      .select('subject_id')
      .eq('id', input.taskId)
      .eq('kind', 'assigned')
      .eq('created_by', staff.profileId)
      .maybeSingle(),
    supabase.from('class_subjects').select('id, subject_id').in('id', classIds),
  ]);
  if (!task?.subject_id) return { ok: false, error: 'That task wasn’t found.' };
  if (
    (classSubjects ?? []).length !== classIds.length ||
    !(classSubjects ?? []).every((c) => c.subject_id === task.subject_id)
  ) {
    return { ok: false, error: 'A task is for one subject: choose classes of the same subject.' };
  }

  const { error } = await supabase.from('task_classes').upsert(
    classIds.map((id) => ({
      task_id: input.taskId,
      school_id: staff.schoolId,
      class_subject_id: id,
    })),
    { onConflict: 'task_id,class_subject_id', ignoreDuplicates: true },
  );
  if (error) return { ok: false, error: 'We couldn’t send the task to your classes.' };
  revalidatePath('/set-work');
  return { ok: true };
}

/** Deletes a task: its files first (through the Storage API), then the task itself. */
export async function deleteTask(taskId: string): Promise<Failed | never> {
  const staff = await currentStaff();
  if (!staff) return { ok: false, error: 'Please sign in again.' };
  if (!UUID.test(taskId)) return { ok: false, error: 'That task wasn’t found.' };

  const supabase = await createClient();
  const folder = `${staff.schoolId}/${taskId}`;
  const { data: files } = await supabase.storage
    .from(TASK_FILES_BUCKET)
    .list(folder, { limit: 1000 });
  if (files?.length) {
    await supabase.storage.from(TASK_FILES_BUCKET).remove(files.map((f) => `${folder}/${f.name}`));
  }
  // Anything the remove missed is queued for clean-up by a trigger on delete.
  const { data, error } = await supabase
    .from('tasks')
    .delete()
    .eq('id', taskId)
    .eq('created_by', staff.profileId)
    .select('id');
  if (error || !data?.length) return { ok: false, error: 'We couldn’t delete that task.' };

  revalidatePath('/set-work');
  redirect('/set-work');
}
