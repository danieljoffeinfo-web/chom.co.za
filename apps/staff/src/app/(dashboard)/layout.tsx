import { redirect } from 'next/navigation';
import type { ReactNode } from 'react';

import { currentStaff } from '@/lib/current-staff';
import { personInitials } from '@/lib/staff';

import { Shell } from './shell';

/** Every dashboard page: only active teachers and school admins get in. */
export default async function DashboardLayout({ children }: { children: ReactNode }) {
  const staff = await currentStaff();
  // /start links a first sign-in to the roster, or explains why they can't come in.
  if (!staff) redirect('/start');

  const roleLabel = [
    staff.roles.includes('teacher') ? 'Teacher' : null,
    staff.roles.includes('school_admin') ? 'School admin' : null,
  ]
    .filter(Boolean)
    .join(' · ');

  return (
    <Shell
      schoolName={staff.schoolName}
      roleLabel={staff.yearLabel ? `${roleLabel} · ${staff.yearLabel}` : roleLabel}
      initials={personInitials(staff.fullName)}
      name={staff.name}
    >
      {children}
    </Shell>
  );
}
