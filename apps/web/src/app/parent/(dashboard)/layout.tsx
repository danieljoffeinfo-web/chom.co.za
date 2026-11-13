import { redirect } from 'next/navigation';
import type { ReactNode } from 'react';

import { currentLinks, currentParent } from '@/lib/parent/current-parent';
import { gradeAndClasses, needsConsent, personInitials } from '@/lib/parent/parent';

import { ParentShell } from './shell';

/**
 * Every parent dashboard page. Parents who still owe consent for a child go to the
 * consent screen first; anyone with no parent link goes back to /start.
 */
export default async function ParentDashboardLayout({ children }: { children: ReactNode }) {
  const [links, parent] = await Promise.all([currentLinks(), currentParent()]);
  if (!parent || !links.length) redirect('/start');
  if (needsConsent(links).length) redirect('/parent/consent');

  return (
    <ParentShell
      name={parent.name}
      initials={personInitials(parent.fullName)}
      kids={parent.children.map((c) => ({
        id: c.id,
        name: c.name,
        initials: personInitials(c.fullName),
        schoolName: c.schoolName,
        detail: gradeAndClasses(c.grade, c.classes).join(' · '),
      }))}
    >
      {children}
    </ParentShell>
  );
}
