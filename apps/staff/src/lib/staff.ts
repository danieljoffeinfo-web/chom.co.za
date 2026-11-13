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

/** The shape my_staff_dashboard() returns (see its migration). */
type DashboardRow = {
  profile_id: string;
  full_name: string;
  preferred_name: string | null;
  school_id: string;
  school_name: string;
  roles: StaffRole[] | null;
  year_label: string | null;
  classes: {
    class_subject_id: string;
    class_id: string;
    class_name: string;
    grade: number;
    subject_name: string;
    learners: number;
    onboarded: number;
  }[];
};

/**
 * Who the signed-in staff member is, their school and current year, and the classes
 * they teach this year with learner and onboarding counts, in one database call
 * (public.my_staff_dashboard). It runs as the signed-in person, so row-level security
 * decides what comes back.
 *
 * Returns null if they aren't an active teacher or school admin anywhere.
 */
export async function loadStaffContext(supabase: Client): Promise<StaffContext | null> {
  const { data, error } = await supabase.rpc('my_staff_dashboard');
  if (error) throw error;
  if (!data) return null;

  const row = data as DashboardRow;
  return {
    profileId: row.profile_id,
    name: row.preferred_name ?? row.full_name.split(' ')[0] ?? row.full_name,
    fullName: row.full_name,
    roles: row.roles ?? [],
    schoolId: row.school_id,
    schoolName: row.school_name,
    yearLabel: row.year_label,
    classes: row.classes.map((c) => ({
      classSubjectId: c.class_subject_id,
      classId: c.class_id,
      className: c.class_name,
      grade: c.grade,
      subjectName: c.subject_name,
      learners: c.learners,
      onboarded: c.onboarded,
    })),
  };
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
