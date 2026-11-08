import { NextResponse } from 'next/server';

import { loadStudentContext } from '@/lib/student';
import {
  TASK_SELECT,
  type TaskRow,
  crossSite,
  endOfDaySast,
  noStore,
  toStudentTask,
} from '@/lib/student-tasks';
import { createClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

/**
 * The signed-in student's tasks this school year: work their teachers set for their
 * classes (with notes and files) and their own reminders, each with whether they've
 * ticked it off. Row-level security decides which tasks come back.
 */
export async function GET() {
  const supabase = await createClient();
  const student = await loadStudentContext(supabase);
  if (!student) {
    return NextResponse.json({ error: 'not_a_student' }, { status: 401, headers: noStore });
  }

  const [tasksRes, doneRes] = await Promise.all([
    supabase
      .from('tasks')
      .select(TASK_SELECT)
      .eq('academic_year_id', student.academicYearId)
      .order('due_at', { ascending: true, nullsFirst: false })
      .order('created_at', { ascending: true })
      .returns<TaskRow[]>(),
    supabase.from('task_completions').select('task_id').eq('student_profile_id', student.profileId),
  ]);
  if (tasksRes.error || doneRes.error) {
    return NextResponse.json({ error: 'load_failed' }, { status: 500, headers: noStore });
  }

  const done = new Set((doneRes.data ?? []).map((c) => c.task_id));
  return NextResponse.json(
    { tasks: (tasksRes.data ?? []).map((t) => toStudentTask(t, done.has(t.id))) },
    { headers: noStore },
  );
}

/** A student adds their own reminder: a title and, if they like, a due date. */
export async function POST(request: Request) {
  const refused = crossSite(request);
  if (refused) return refused;

  const supabase = await createClient();
  const student = await loadStudentContext(supabase);
  if (!student) {
    return NextResponse.json({ error: 'not_a_student' }, { status: 401, headers: noStore });
  }

  const body = (await request.json().catch(() => null)) as {
    title?: unknown;
    dueOn?: unknown;
  } | null;
  const title = typeof body?.title === 'string' ? body.title.trim() : '';
  const dueOn = typeof body?.dueOn === 'string' && body.dueOn ? body.dueOn : null;
  if (!title || title.length > 200) {
    return NextResponse.json({ error: 'title_required' }, { status: 400, headers: noStore });
  }
  if (dueOn && !/^\d{4}-\d{2}-\d{2}$/.test(dueOn)) {
    return NextResponse.json({ error: 'bad_due_date' }, { status: 400, headers: noStore });
  }

  const { data, error } = await supabase
    .from('tasks')
    .insert({
      school_id: student.schoolId,
      academic_year_id: student.academicYearId,
      kind: 'personal',
      title,
      due_at: dueOn ? endOfDaySast(dueOn) : null,
      created_by: student.profileId,
    })
    .select(TASK_SELECT)
    .returns<TaskRow[]>()
    .single();
  if (error || !data) {
    return NextResponse.json({ error: 'save_failed' }, { status: 500, headers: noStore });
  }
  return NextResponse.json({ task: toStudentTask(data, false) }, { status: 201, headers: noStore });
}
