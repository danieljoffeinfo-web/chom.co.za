import type { Enums } from '@chom/api';

import type { createClient } from './supabase/server';

type Client = Awaited<ReturnType<typeof createClient>>;

export type StaffRole = Extract<Enums<'membership_role'>, 'teacher' | 'school_admin'>;

/** One subject the teacher teaches to one class, e.g. Mathematics to 11A. */
export type TeachingClass = {
  classSubjectId: string;
  classId: string;
  className: string;
  grade: number;
  subjectName: string;
  learners: number;
  onboarded: number;
};

export type StaffContext = {
  profileId: string;
  name: string;
  fullName: string;
  roles: StaffRole[];
  schoolId: string;
  schoolName: string;
  yearLabel: string | null;
  classes: TeachingClass[];
};

const STAFF_ROLES: StaffRole[] = ['teacher', 'school_admin'];

/**
 * Who the signed-in staff member is, their school and current year, and the classes
 * they teach this year with learner and onboarding counts. Every query runs as the
 * signed-in person, so row-level security decides what comes back.
 *
 * Returns null if they aren't an active teacher or school admin anywhere.
 */
export async function loadStaffContext(supabase: Client): Promise<StaffContext | null> {
  const { data: claims } = await supabase.auth.getClaims();
  const userId = claims?.claims.sub;
  if (!userId) return null;

  const { data: profile } = await supabase
    .from('profiles')
    .select('id, full_name, preferred_name')
    .eq('user_id', userId)
    .maybeSingle();
  if (!profile) return null;

  const { data: memberships } = await supabase
    .from('school_memberships')
    .select('school_id, role, schools(name)')
    .eq('profile_id', profile.id)
    .eq('status', 'active')
    .in('role', STAFF_ROLES);
  if (!memberships?.length) return null;

  // Someone on staff at more than one school sees the first for now; a school
  // switcher comes later. Prefer a school where they teach.
  const first = memberships.find((m) => m.role === 'teacher') ?? memberships[0];
  if (!first) return null;
  const schoolId = first.school_id;
  const roles = memberships.filter((m) => m.school_id === schoolId).map((m) => m.role as StaffRole);

  const { data: year } = await supabase
    .from('academic_years')
    .select('id, label')
    .eq('school_id', schoolId)
    .eq('is_current', true)
    .maybeSingle();

  const classes = year ? await loadTeachingClasses(supabase, profile.id, year.id) : [];

  return {
    profileId: profile.id,
    name: profile.preferred_name ?? profile.full_name.split(' ')[0] ?? profile.full_name,
    fullName: profile.full_name,
    roles,
    schoolId,
    schoolName: first.schools?.name ?? '',
    yearLabel: year?.label ?? null,
    classes,
  };
}

async function loadTeachingClasses(
  supabase: Client,
  profileId: string,
  academicYearId: string,
): Promise<TeachingClass[]> {
  const { data: allocations } = await supabase
    .from('teaching_allocations')
    .select(
      'class_subjects!inner(id, subjects(name), classes!inner(id, name, grade, academic_year_id))',
    )
    .eq('teacher_profile_id', profileId)
    .eq('class_subjects.classes.academic_year_id', academicYearId);
  if (!allocations?.length) return [];

  const classIds = [...new Set(allocations.map((a) => a.class_subjects.classes.id))];

  const { data: enrolments } = await supabase
    .from('enrolments')
    .select('class_id, student_profile_id')
    .in('class_id', classIds);

  const studentIds = [...new Set((enrolments ?? []).map((e) => e.student_profile_id))];
  const { data: onboardedRows } = studentIds.length
    ? await supabase
        .from('student_study_profiles')
        .select('student_profile_id')
        .eq('academic_year_id', academicYearId)
        .in('student_profile_id', studentIds)
        .not('onboarding_completed_at', 'is', null)
    : { data: [] };
  const onboarded = new Set((onboardedRows ?? []).map((r) => r.student_profile_id));

  const learnersByClass = new Map<string, string[]>();
  for (const e of enrolments ?? []) {
    learnersByClass.set(e.class_id, [
      ...(learnersByClass.get(e.class_id) ?? []),
      e.student_profile_id,
    ]);
  }

  return allocations
    .map(({ class_subjects: cs }) => {
      const learners = learnersByClass.get(cs.classes.id) ?? [];
      return {
        classSubjectId: cs.id,
        classId: cs.classes.id,
        className: cs.classes.name,
        grade: cs.classes.grade,
        subjectName: cs.subjects?.name ?? 'Subject',
        learners: learners.length,
        onboarded: learners.filter((id) => onboarded.has(id)).length,
      };
    })
    .sort(
      (a, b) =>
        a.grade - b.grade ||
        a.className.localeCompare(b.className) ||
        a.subjectName.localeCompare(b.subjectName),
    );
}

/** "Mathematics" → "MA", "Life Sciences" → "LS": the badge on a class card. */
export function subjectInitials(name: string): string {
  const words = name.split(/\s+/).filter((w) => /^[A-Za-z]/.test(w));
  const [first, second] = words;
  const letters = first && second ? first.charAt(0) + second.charAt(0) : name.slice(0, 2);
  return letters.toUpperCase();
}

/** "Sizwe Dlamini" → "SD": the avatar in the quick-actions dock. */
export function personInitials(fullName: string): string {
  return fullName
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((word) => word.charAt(0).toUpperCase())
    .join('');
}

export function gradeLabel(grade: number): string {
  return grade === 0 ? 'Grade R' : `Grade ${grade}`;
}
