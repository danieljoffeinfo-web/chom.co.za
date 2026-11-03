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

/** The shape my_student_dashboard() returns (see its migration). */
type DashboardRow = {
  profile_id: string;
  full_name: string;
  preferred_name: string | null;
  school_id: string;
  school_name: string;
  academic_year_id: string;
  year_label: string;
  grade: number | null;
  class_names: string[];
  subjects: {
    id: string;
    name: string;
    category: string | null;
    sort_order: number;
  }[];
  study_profile: Tables<'student_study_profiles'> | null;
  goals: Tables<'student_subject_goals'>[] | null;
};

/**
 * Everything the signed-in student's home and onboarding need: who they are, their
 * school and current year, their classes and subjects, and any answers already saved,
 * in one database call (public.my_student_dashboard). It runs as the signed-in person,
 * so row-level security decides what comes back.
 *
 * Returns null if they aren't an active student with a current year.
 */
export async function loadStudentContext(supabase: Client): Promise<StudentContext | null> {
  const { data, error } = await supabase.rpc('my_student_dashboard');
  if (error) throw error;
  if (!data) return null;

  const row = data as DashboardRow;
  return {
    profileId: row.profile_id,
    name: row.preferred_name ?? row.full_name,
    schoolId: row.school_id,
    schoolName: row.school_name,
    academicYearId: row.academic_year_id,
    yearLabel: row.year_label,
    grade: row.grade,
    classNames: row.class_names ?? [],
    subjects: (row.subjects ?? []).map((subject) => ({
      id: subject.id,
      name: subject.name,
      category: subject.category,
      sortOrder: subject.sort_order,
    })),
    studyProfile: row.study_profile,
    goals: row.goals ?? [],
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
