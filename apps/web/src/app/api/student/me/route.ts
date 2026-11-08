import { isAuthRetryableFetchError } from '@supabase/supabase-js';
import { NextResponse } from 'next/server';

import { loadStudentContext } from '@/lib/student';
import { createClient } from '@/lib/supabase/server';

// Per person, per request: never cached.
export const dynamic = 'force-dynamic';
const noStore = { 'Cache-Control': 'private, no-store' };

/**
 * What the student dashboard (the prototype at /app) shows about the signed-in
 * student: who they are, their class and school, their subjects with teachers, the
 * goals they set at onboarding, and from the school's calendar: today's date, the term
 * and week, upcoming exams, and each subject's unit plan (done, now, upcoming).
 * Everything is read as the student, so row-level security decides what comes back.
 *
 * 401 when nobody is signed in; 403 when someone is, but not as a student (a teacher or
 * parent in the same browser). On chom.co.za the dashboard then sends them to sign in,
 * or offers their own dashboard; it never shows sample data to a real visitor.
 */
export async function GET() {
  const supabase = await createClient();
  const { data: claims, error: claimsError } = await supabase.auth.getClaims();
  if (!claims?.claims) {
    // Auth unreachable (a network error or 5xx) is "try again", not "sign in again".
    return isRetryableAuthError(claimsError)
      ? NextResponse.json({ error: 'unavailable' }, { status: 500, headers: noStore })
      : NextResponse.json({ error: 'signed_out' }, { status: 401, headers: noStore });
  }
  const student = await loadStudentContext(supabase);
  if (!student) {
    // Only a confirmed non-student gets 403 ("this is the student dashboard"). A failed
    // lookup, or a student whose school has no current year, gets 500: the dashboard
    // then offers to try again instead of telling a student they're someone else.
    const isStudent = await hasStudentMembership(supabase, claims.claims.sub);
    return isStudent === false
      ? NextResponse.json({ error: 'not_a_student' }, { status: 403, headers: noStore })
      : NextResponse.json({ error: 'unavailable' }, { status: 500, headers: noStore });
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

  // The school's calendar and this grade's unit plan. "Today" is the school's: a demo
  // school's fixed date, otherwise today in South Africa.
  const grade = student.grade;
  const subjectIds = student.subjects.map((s) => s.id);
  const [todayRes, termsRes, examsRes, contentEndRes, subjectRowsRes, scheduleRes] =
    await Promise.all([
      supabase.rpc('school_today', { p_school_id: student.schoolId }),
      supabase
        .from('school_terms')
        .select('term_number, starts_on, ends_on')
        .eq('academic_year_id', student.academicYearId)
        .order('term_number'),
      grade === null
        ? Promise.resolve({ data: [] })
        : supabase
            .from('exam_windows')
            .select('label, kind, starts_on, ends_on, is_approximate')
            .eq('academic_year_id', student.academicYearId)
            .lte('min_grade', grade)
            .gte('max_grade', grade)
            .order('starts_on'),
      grade === null
        ? Promise.resolve({ data: null })
        : supabase
            .from('grade_content_end_dates')
            .select('content_ends_on')
            .eq('academic_year_id', student.academicYearId)
            .eq('grade', grade)
            .maybeSingle(),
      subjectIds.length
        ? supabase.from('subjects').select('id, curriculum_subject_id').in('id', subjectIds)
        : Promise.resolve({ data: [] }),
      grade === null
        ? Promise.resolve({ data: [] })
        : supabase
            .from('unit_schedules')
            .select(
              'starts_on, ends_on, term_number, curriculum_units!inner(title, position, grade, curriculum_subject_id)',
            )
            .eq('academic_year_id', student.academicYearId)
            .eq('curriculum_units.grade', grade),
    ]);

  const today: string =
    todayRes.data ?? new Date().toLocaleDateString('en-CA', { timeZone: 'Africa/Johannesburg' });
  const terms = termsRes.data ?? [];
  const term = terms.find((t) => t.starts_on <= today && today <= t.ends_on) ?? null;
  const daysBetween = (from: string, to: string) =>
    Math.round((Date.parse(`${to}T00:00:00Z`) - Date.parse(`${from}T00:00:00Z`)) / 86_400_000);
  const contentEndsOn = contentEndRes.data?.content_ends_on ?? null;

  const curriculumOf = new Map(
    (subjectRowsRes.data ?? []).map((s) => [s.id, s.curriculum_subject_id] as const),
  );
  const unitsByCurriculumSubject = new Map<
    string,
    { title: string; position: number; startsOn: string; endsOn: string; term: number | null }[]
  >();
  for (const row of scheduleRes.data ?? []) {
    const u = row.curriculum_units;
    const list = unitsByCurriculumSubject.get(u.curriculum_subject_id) ?? [];
    list.push({
      title: u.title,
      position: u.position,
      startsOn: row.starts_on,
      endsOn: row.ends_on,
      term: row.term_number,
    });
    unitsByCurriculumSubject.set(u.curriculum_subject_id, list);
  }
  const unitsFor = (subjectId: string) => {
    const curriculumSubjectId = curriculumOf.get(subjectId);
    const units = curriculumSubjectId
      ? (unitsByCurriculumSubject.get(curriculumSubjectId) ?? [])
      : [];
    return units
      .sort((a, b) => a.position - b.position)
      .map(({ title, startsOn, endsOn, term: unitTerm }) => ({
        title,
        startsOn,
        endsOn,
        term: unitTerm,
        status: endsOn < today ? 'done' : startsOn <= today ? 'now' : 'upcoming',
      }));
  };

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
        units: unitsFor(s.id),
      })),
      today,
      termCount: terms.length,
      term: term && {
        number: term.term_number,
        week: Math.floor(daysBetween(term.starts_on, today) / 7) + 1,
        endsOn: term.ends_on,
      },
      contentEndsOn,
      // Exams still to come or under way, soonest first.
      exams: (examsRes.data ?? [])
        .filter((e) => e.ends_on >= today)
        .map((e) => ({
          label: e.label,
          startsOn: e.starts_on,
          endsOn: e.ends_on,
          isApproximate: e.is_approximate,
          inProgress: e.starts_on <= today,
        })),
      onboardingComplete: Boolean(student.studyProfile?.onboarding_completed_at),
    },
    { headers: noStore },
  );
}

/** True or false if we could tell whether this login is an active student; null if not. */
async function hasStudentMembership(
  supabase: Awaited<ReturnType<typeof createClient>>,
  userId: string,
): Promise<boolean | null> {
  const { data: profile, error } = await supabase
    .from('profiles')
    .select('id')
    .eq('user_id', userId)
    .maybeSingle();
  if (error) return null;
  if (!profile) return false;
  const { data: memberships, error: membershipError } = await supabase
    .from('school_memberships')
    .select('id')
    .eq('profile_id', profile.id)
    .eq('role', 'student')
    .eq('status', 'active')
    .limit(1);
  if (membershipError) return null;
  return memberships.length > 0;
}

function isRetryableAuthError(error: unknown): boolean {
  if (!error) return false;
  if (isAuthRetryableFetchError(error)) return true;
  const status = (error as { status?: unknown }).status;
  return typeof status === 'number' && status >= 500;
}
