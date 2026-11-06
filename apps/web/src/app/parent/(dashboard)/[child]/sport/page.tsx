import { ComingSoon } from '@chom/dashboard';
import { notFound } from 'next/navigation';

import { findChild } from '@/lib/parent/current-parent';

export const metadata = { title: 'Sport · Chom Parent' };

export default async function Sport({ params }: { params: Promise<{ child: string }> }) {
  const { child: childId } = await params;
  const { child } = await findChild(childId);
  if (!child) notFound();

  return (
    <ComingSoon
      title="Sport"
      icon="ball"
      intro={`${child.name}’s teams, clubs and matches, from their coaches.`}
      points={[
        'Teams, training times and venues',
        'Fixtures with transport and kit notes, and changes on the day',
        `Confirm whether ${child.name} can play, in one tap`,
        'Team selections and results',
      ]}
    />
  );
}
