import type { StaffContext } from './staff';
import type { createClient } from './supabase/server';
import { TASK_FILES_BUCKET } from './task-files';

type Client = Awaited<ReturnType<typeof createClient>>;

/** A task the teacher set, as Set Work lists it. */
export type SetTask = {
  id: string;
  title: string;
  notes: string | null;
  dueAt: string;
  subject: string | null;
  /** The classes it went to (empty: saved but never sent, e.g. an upload failed). */
  classes: { classSubjectId: string; classId: string; name: string }[];
  files: { id: string; name: string; size: number; path: string }[];
  /** Learners who have ticked it off, and learners it went to. */
  done: number;
  learners: number;
};

type Row = {
  id: string;
  title: string;
  notes: string | null;
  due_at: string | null;
  subjects: { name: string } | null;
  task_classes: { class_subject_id: string }[];
  task_attachments: { id: string; file_name: string; size_bytes: number; storage_path: string }[];
  task_completions: { count: number }[];
};

const SELECT =
  'id, title, notes, due_at, subjects(name), task_classes(class_subject_id), task_attachments(id, file_name, size_bytes, storage_path), task_completions(count)';

function toSetTask(row: Row, staff: StaffContext): SetTask {
  const byId = new Map(staff.classes.map((c) => [c.classSubjectId, c]));
  const classes = row.task_classes.flatMap((tc) => {
    const c = byId.get(tc.class_subject_id);
    return c ? [{ classSubjectId: c.classSubjectId, classId: c.classId, name: c.className }] : [];
  });
  return {
    id: row.id,
    title: row.title,
    notes: row.notes,
    dueAt: row.due_at ?? '',
    subject: row.subjects?.name ?? null,
    classes,
    files: row.task_attachments.map((a) => ({
      id: a.id,
      name: a.file_name,
      size: a.size_bytes,
      path: a.storage_path,
    })),
    done: row.task_completions[0]?.count ?? 0,
    learners: row.task_classes.reduce(
      (sum, tc) => sum + (byId.get(tc.class_subject_id)?.learners ?? 0),
      0,
    ),
  };
}

/** The work this teacher has set, latest due date first. */
export async function loadSetTasks(supabase: Client, staff: StaffContext): Promise<SetTask[]> {
  const { data, error } = await supabase
    .from('tasks')
    .select(SELECT)
    .eq('kind', 'assigned')
    .eq('created_by', staff.profileId)
    .order('due_at', { ascending: false })
    .returns<Row[]>();
  if (error) throw error;
  return (data ?? []).map((row) => toSetTask(row, staff));
}

/** One task, with who in each class has ticked it off and links to its files. */
export async function loadSetTask(supabase: Client, staff: StaffContext, id: string) {
  const { data: row, error } = await supabase
    .from('tasks')
    .select(SELECT)
    .eq('id', id)
    .eq('created_by', staff.profileId)
    .returns<Row[]>()
    .maybeSingle();
  if (error) throw error;
  if (!row) return null;
  const task = toSetTask(row, staff);

  const classIds = task.classes.map((c) => c.classId);
  const [{ data: enrolments }, { data: completions }, signed] = await Promise.all([
    classIds.length
      ? supabase.from('enrolments').select('class_id, student_profile_id').in('class_id', classIds)
      : Promise.resolve({ data: [] as { class_id: string; student_profile_id: string }[] }),
    supabase.from('task_completions').select('student_profile_id').eq('task_id', id),
    task.files.length
      ? supabase.storage.from(TASK_FILES_BUCKET).createSignedUrls(
          task.files.map((f) => f.path),
          60 * 30,
          { download: true },
        )
      : Promise.resolve({ data: [] }),
  ]);

  const studentIds = [...new Set((enrolments ?? []).map((e) => e.student_profile_id))];
  const { data: profiles } = studentIds.length
    ? await supabase.from('profiles').select('id, full_name').in('id', studentIds)
    : { data: [] };
  const names = new Map((profiles ?? []).map((p) => [p.id, p.full_name]));
  const done = new Set((completions ?? []).map((c) => c.student_profile_id));
  const urls = new Map((signed.data ?? []).map((s) => [s.path, s.signedUrl]));

  return {
    task,
    files: task.files.map((f) => ({ ...f, url: urls.get(f.path) ?? null })),
    classes: task.classes.map((c) => ({
      ...c,
      learners: (enrolments ?? [])
        .filter((e) => e.class_id === c.classId)
        .map((e) => ({
          id: e.student_profile_id,
          name: names.get(e.student_profile_id) ?? 'A learner',
          done: done.has(e.student_profile_id),
        }))
        .sort((a, b) => Number(a.done) - Number(b.done) || a.name.localeCompare(b.name)),
    })),
  };
}

const DAY = new Intl.DateTimeFormat('en-ZA', {
  weekday: 'short',
  day: 'numeric',
  month: 'short',
  timeZone: 'Africa/Johannesburg',
});
const TIME = new Intl.DateTimeFormat('en-ZA', {
  hour: '2-digit',
  minute: '2-digit',
  hourCycle: 'h23',
  timeZone: 'Africa/Johannesburg',
});

/** "Due Thu 12 Nov, 15:00". */
export function dueLabel(dueAt: string): string {
  const d = new Date(dueAt);
  return `Due ${DAY.format(d)}, ${TIME.format(d)}`;
}
