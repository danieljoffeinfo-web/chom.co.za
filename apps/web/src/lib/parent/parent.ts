import type { Enums } from '@chom/api';

import type { createClient } from '../supabase/server';

type Client = Awaited<ReturnType<typeof createClient>>;

export type Relationship = Enums<'guardian_relationship'>;
export type LinkStatus = Enums<'guardianship_status'>;

/** One of the signed-in parent's links to a child (never a blocked one). */
export type GuardianLink = {
  guardianshipId: string;
  schoolId: string;
  schoolName: string;
  childId: string;
  childName: string;
  grade: number | null;
  relationship: Relationship;
  isPrimary: boolean;
  status: LinkStatus;
  consented: boolean;
};

export type ChildSubject = {
  id: string;
  name: string;
  category: string | null;
  teachers: string[];
  targetPercent: number | null;
  isFocus: boolean;
};

export type ChildStudy = {
  onboardingCompletedAt: string | null;
  sessionLength: Enums<'study_session_length'> | null;
  studyMethods: Enums<'study_method'>[];
  studyTimes: Enums<'study_time'>[];
};

/** A child the parent may see: an active link with current consent. */
export type Child = {
  id: string;
  guardianshipId: string;
  name: string;
  fullName: string;
  relationship: Relationship;
  isPrimary: boolean;
  schoolId: string;
  schoolName: string;
  yearLabel: string | null;
  grade: number | null;
  classes: string[];
  subjects: ChildSubject[];
  study: ChildStudy | null;
};

export type ParentContext = {
  profileId: string;
  name: string;
  fullName: string;
  children: Child[];
};

/** The shape my_parent_dashboard() returns (see its migration). */
type DashboardRow = {
  profile_id: string;
  full_name: string;
  preferred_name: string | null;
  children: {
    guardianship_id: string;
    profile_id: string;
    full_name: string;
    preferred_name: string | null;
    relationship: Relationship;
    is_primary: boolean;
    school_id: string;
    school_name: string;
    year_label: string | null;
    grade: number | null;
    classes: string[];
    study: {
      onboarding_completed_at: string | null;
      session_length: Enums<'study_session_length'> | null;
      study_methods: Enums<'study_method'>[] | null;
      study_times: Enums<'study_time'>[] | null;
    } | null;
    subjects: {
      subject_id: string;
      name: string;
      category: string | null;
      teachers: string[];
      target_percent: number | null;
      is_focus: boolean;
    }[];
  }[];
};

const firstName = (preferred: string | null, full: string) =>
  preferred ?? full.split(' ')[0] ?? full;

/**
 * The signed-in parent's links to their children, for the consent screen and to know
 * whether consent is still needed. Names only: child data needs consent first.
 */
export async function loadGuardianLinks(supabase: Client): Promise<GuardianLink[]> {
  const { data, error } = await supabase.rpc('my_guardian_links');
  if (error) throw error;
  return (data ?? []).map((l) => ({
    guardianshipId: l.guardianship_id,
    schoolId: l.school_id,
    schoolName: l.school_name,
    childId: l.student_profile_id,
    childName: l.student_name,
    grade: l.grade,
    relationship: l.relationship,
    isPrimary: l.is_primary,
    status: l.status,
    consented: l.consented,
  }));
}

/** Links that still need the parent's consent before they can see the child. */
export function needsConsent(links: GuardianLink[]): GuardianLink[] {
  return links.filter((l) => !l.consented && (l.status === 'invited' || l.status === 'active'));
}

/**
 * Who the signed-in parent is, and every child they may see across schools, in one
 * database call (public.my_parent_dashboard). It runs as the parent, so row-level
 * security decides which children come back: only consented, unblocked links.
 *
 * Returns null if the signed-in person has no profile.
 */
export async function loadParentContext(supabase: Client): Promise<ParentContext | null> {
  const { data, error } = await supabase.rpc('my_parent_dashboard');
  if (error) throw error;
  if (!data) return null;

  const row = data as DashboardRow;
  return {
    profileId: row.profile_id,
    name: firstName(row.preferred_name, row.full_name),
    fullName: row.full_name,
    children: row.children.map((c) => ({
      id: c.profile_id,
      guardianshipId: c.guardianship_id,
      name: firstName(c.preferred_name, c.full_name),
      fullName: c.full_name,
      relationship: c.relationship,
      isPrimary: c.is_primary,
      schoolId: c.school_id,
      schoolName: c.school_name,
      yearLabel: c.year_label,
      grade: c.grade,
      classes: c.classes,
      study: c.study
        ? {
            onboardingCompletedAt: c.study.onboarding_completed_at,
            sessionLength: c.study.session_length,
            studyMethods: c.study.study_methods ?? [],
            studyTimes: c.study.study_times ?? [],
          }
        : null,
      subjects: c.subjects.map((s) => ({
        id: s.subject_id,
        name: s.name,
        category: s.category,
        teachers: s.teachers,
        targetPercent: s.target_percent,
        isFocus: s.is_focus,
      })),
    })),
  };
}

export function gradeLabel(grade: number | null): string | null {
  if (grade === null) return null;
  return grade === 0 ? 'Grade R' : `Grade ${grade}`;
}

/** "Amara Nwosu" → "AN". */
export function personInitials(fullName: string): string {
  return fullName
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((word) => word.charAt(0).toUpperCase())
    .join('');
}

/** The Future tab is full for Grades 11–12 and lighter below (spec §5.6). */
export function futureStage(grade: number | null): 'university' | 'subject_choice' | 'pathways' {
  if (grade !== null && grade >= 11) return 'university';
  if (grade === 9) return 'subject_choice';
  return 'pathways';
}

export const RELATIONSHIP_LABELS: Record<Relationship, string> = {
  mother: 'Mother',
  father: 'Father',
  guardian: 'Guardian',
  other: 'Family member',
};
