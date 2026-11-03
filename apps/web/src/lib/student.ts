import type { Enums, Tables } from '@chom/api';

import type { createClient } from './supabase/server';

type Client = Awaited<ReturnType<typeof createClient>>;

export type StudentSubject = {
  id: string;
  name: string;
  category: string | null;
  sortOrder: number;
};

export type StudentContext = {
  profileId: string;
  name: string;
  schoolId: string;
  schoolName: string;
  academicYearId: string;
  yearLabel: string;
  grade: number | null;
  classNames: string[];
  subjects: StudentSubject[];
  studyProfile: Tables<'student_study_profiles'> | null;
  goals: Tables<'student_subject_goals'>[];
};

export type StudyMethod = Enums<'study_method'>;
export type StudyTime = Enums<'study_time'>;
export type SessionLength = Enums<'study_session_length'>;

/**
 * Everything the signed-in student's onboarding needs: who they are, their school and
 * current year, their classes and subjects, and any answers already saved. Every query
 * runs as the student, so row-level security decides what comes back.
 *
 * Returns null if the signed-in person isn't an active student with a current year.
 */
export async function loadStudentContext(supabase: Client): Promise<StudentContext | null> {
  const { data: claims } = await supabase.auth.getClaims();
  const userId = claims?.claims.sub;
  if (!userId) return null;

  const { data: profile } = await supabase
    .from('profiles')
    .select('id, full_name, preferred_name')
    .eq('user_id', userId)
    .maybeSingle();
  if (!profile) return null;

  const { data: membership } = await supabase
    .from('school_memberships')
    .select('school_id, schools(name)')
    .eq('profile_id', profile.id)
    .eq('role', 'student')
    .eq('status', 'active')
    .limit(1)
    .maybeSingle();
  if (!membership) return null;

  const { data: year } = await supabase
    .from('academic_years')
    .select('id, label')
    .eq('school_id', membership.school_id)
    .eq('is_current', true)
    .maybeSingle();
  if (!year) return null;

  const { data: enrolments } = await supabase
    .from('enrolments')
    .select(
      'classes!inner(name, grade, academic_year_id, class_subjects(subjects(id, name, curriculum_subjects(category, sort_order))))',
    )
    .eq('student_profile_id', profile.id)
    .eq('classes.academic_year_id', year.id);

  const subjects = new Map<string, StudentSubject>();
  const classNames: string[] = [];
  let grade: number | null = null;
  for (const enrolment of enrolments ?? []) {
    const cls = enrolment.classes;
    classNames.push(cls.name);
    grade = grade ?? cls.grade;
    for (const classSubject of cls.class_subjects) {
      const subject = classSubject.subjects;
      if (!subject || subjects.has(subject.id)) continue;
      subjects.set(subject.id, {
        id: subject.id,
        name: subject.name,
        category: subject.curriculum_subjects?.category ?? null,
        sortOrder: subject.curriculum_subjects?.sort_order ?? 1000,
      });
    }
  }

  const [{ data: studyProfile }, { data: goals }] = await Promise.all([
    supabase
      .from('student_study_profiles')
      .select('*')
      .eq('student_profile_id', profile.id)
      .eq('academic_year_id', year.id)
      .maybeSingle(),
    supabase
      .from('student_subject_goals')
      .select('*')
      .eq('student_profile_id', profile.id)
      .eq('academic_year_id', year.id),
  ]);

  return {
    profileId: profile.id,
    name: profile.preferred_name ?? profile.full_name,
    schoolId: membership.school_id,
    schoolName: membership.schools?.name ?? '',
    academicYearId: year.id,
    yearLabel: year.label,
    grade,
    classNames,
    subjects: [...subjects.values()].sort(
      (a, b) => a.sortOrder - b.sortOrder || a.name.localeCompare(b.name),
    ),
    studyProfile: studyProfile ?? null,
    goals: goals ?? [],
  };
}

export const SESSION_LENGTHS: { value: SessionLength; label: string }[] = [
  { value: 'minutes_15', label: '15 min' },
  { value: 'minutes_30', label: '30 min' },
  { value: 'minutes_45', label: '45 min' },
  { value: 'minutes_60_plus', label: '60+ min' },
];

export const STUDY_METHODS: { value: StudyMethod; label: string }[] = [
  { value: 'pen_and_paper', label: 'Pen and paper' },
  { value: 'videos', label: 'Videos' },
  { value: 'ai_chat', label: 'Claude or ChatGPT' },
  { value: 'past_papers', label: 'Past papers' },
  { value: 'flashcards', label: 'Flashcards' },
  { value: 'study_group', label: 'Study group' },
];

export const STUDY_TIMES: { value: StudyTime; label: string }[] = [
  { value: 'afternoon', label: 'Afternoon' },
  { value: 'evening', label: 'Evening' },
  { value: 'late_night', label: 'Late night' },
  { value: 'weekends', label: 'Weekends' },
];

export const MAX_FOCUS_SUBJECTS = 3;
