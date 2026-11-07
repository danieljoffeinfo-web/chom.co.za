import { NextResponse } from 'next/server';

import { loadStudentContext } from '@/lib/student';
import { createClient } from '@/lib/supabase/server';

// Per person, per request: never cached.
export const dynamic = 'force-dynamic';
const noStore = { 'Cache-Control': 'private, no-store' };

/**
 * What the student dashboard (the prototype at /app) shows about the signed-in
 * student: who they are, their class and school, their subjects with teachers, and
 * the goals they set at onboarding. Everything is read as the student, so row-level
 * security decides what comes back.
 *
 * 401 when nobody is signed in or the person isn't a student: the dashboard then
 * stays on its sample data.
 */
export async function GET() {
  const supabase = await createClient();
  const student = await loadStudentContext(supabase);
  if (!student) {
    return NextResponse.json({ error: 'not_a_student' }, { status: 401, headers: noStore });
  }

  // Who teaches each of the student's subjects this year, through the classes they're
  // in. Limited to the student's own classes: someone who is also a school admin can
  // see every class's teachers, and those aren't theirs.
  const { data: enrolments } = await supabase
    .from('enrolments')
    .select('class_id')
    .eq('student_profile_id', student.profileId);
  const classIds = [...new Set((enrolments ?? []).map((e) => e.class_id))];
  const { data: allocations } = classIds.length
    ? await supabase
        .from('teaching_allocations')
        .select(
          'teacher_profile_id, class_subjects!inner(subject_id, class_id, classes!inner(academic_year_id))',
        )
        .in('class_subjects.class_id', classIds)
        .eq('class_subjects.classes.academic_year_id', student.academicYearId)
    : { data: [] };

  const teacherIds = [...new Set((allocations ?? []).map((a) => a.teacher_profile_id))];
  const { data: teachers } = teacherIds.length
    ? await supabase.from('profiles').select('id, full_name, preferred_name').in('id', teacherIds)
    : { data: [] };
  const teacherName = new Map(
    (teachers ?? []).map((t) => [t.id, t.preferred_name ?? t.full_name] as const),
  );
  const teachersBySubject = new Map<string, string[]>();
  for (const a of allocations ?? []) {
    const name = teacherName.get(a.teacher_profile_id);
    if (!name) continue;
    const list = teachersBySubject.get(a.class_subjects.subject_id) ?? [];
    if (!list.includes(name)) list.push(name);
    teachersBySubject.set(a.class_subjects.subject_id, list);
  }

  const goals = new Map(student.goals.map((g) => [g.subject_id, g]));
  const fullName = student.name.trim();
  const words = fullName.split(/\s+/);
  const first = words[0] ?? fullName;
  const last = words.length > 1 ? (words[words.length - 1] ?? '') : '';

  return NextResponse.json(
    {
      // Keys the dashboard's on-device storage, so two students on one browser don't
      // share tasks.
      id: student.profileId,
      firstName: first,
      fullName,
      initials: (first.charAt(0) + last.charAt(0)).toUpperCase(),
      grade: student.grade,
      registerClass: student.registerClassName,
      schoolName: student.schoolName,
      yearLabel: student.yearLabel,
      subjects: student.subjects.map((s) => ({
        id: s.id,
        name: s.name,
        teacher: (teachersBySubject.get(s.id) ?? []).join(', '),
        isFocus: goals.get(s.id)?.is_focus ?? false,
        target: goals.get(s.id)?.target_percent ?? null,
      })),
      onboardingComplete: Boolean(student.studyProfile?.onboarding_completed_at),
    },
    { headers: noStore },
  );
}
