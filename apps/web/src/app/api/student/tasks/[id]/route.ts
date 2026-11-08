import { NextResponse } from 'next/server';

import { loadStudentContext } from '@/lib/student';
import { UUID, crossSite, noStore } from '@/lib/student-tasks';
import { createClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

type Params = { params: Promise<{ id: string }> };

/** Tick a task off, or untick it: `{ "done": true | false }`. */
export async function PATCH(request: Request, { params }: Params) {
  const refused = crossSite(request);
  if (refused) return refused;
  const { id } = await params;
  if (!UUID.test(id)) {
    return NextResponse.json({ error: 'not_found' }, { status: 404, headers: noStore });
  }

  const supabase = await createClient();
  const student = await loadStudentContext(supabase);
  if (!student) {
    return NextResponse.json({ error: 'not_a_student' }, { status: 401, headers: noStore });
  }
  const body = (await request.json().catch(() => null)) as { done?: unknown } | null;
  if (typeof body?.done !== 'boolean') {
    return NextResponse.json({ error: 'done_required' }, { status: 400, headers: noStore });
  }

  // Row-level security only lets a student tick tasks they actually have.
  const { error } = body.done
    ? await supabase
        .from('task_completions')
        .upsert(
          { task_id: id, school_id: student.schoolId, student_profile_id: student.profileId },
          { onConflict: 'task_id,student_profile_id', ignoreDuplicates: true },
        )
    : await supabase
        .from('task_completions')
        .delete()
        .eq('task_id', id)
        .eq('student_profile_id', student.profileId);
  if (error) {
    return NextResponse.json({ error: 'save_failed' }, { status: 403, headers: noStore });
  }
  return NextResponse.json({ done: body.done }, { headers: noStore });
}

/** Delete one of the student's own reminders. Tasks a teacher set can't be deleted here. */
export async function DELETE(request: Request, { params }: Params) {
  const refused = crossSite(request);
  if (refused) return refused;
  const { id } = await params;
  if (!UUID.test(id)) {
    return NextResponse.json({ error: 'not_found' }, { status: 404, headers: noStore });
  }

  const supabase = await createClient();
  const student = await loadStudentContext(supabase);
  if (!student) {
    return NextResponse.json({ error: 'not_a_student' }, { status: 401, headers: noStore });
  }
  const { data, error } = await supabase
    .from('tasks')
    .delete()
    .eq('id', id)
    .eq('kind', 'personal')
    .eq('created_by', student.profileId)
    .select('id');
  if (error) {
    return NextResponse.json({ error: 'delete_failed' }, { status: 500, headers: noStore });
  }
  if (!data?.length) {
    return NextResponse.json({ error: 'not_found' }, { status: 404, headers: noStore });
  }
  return new NextResponse(null, { status: 204, headers: noStore });
}
