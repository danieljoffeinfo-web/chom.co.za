import { ComingSoon } from '@chom/dashboard';
import { notFound } from 'next/navigation';

import { findChild } from '@/lib/parent/current-parent';
import { futureStage } from '@/lib/parent/parent';

export const metadata = { title: 'Future · Chom Parent' };

/** Future (spec §5.6): full university view in Grades 11–12, lighter below. */
export default async function Future({ params }: { params: Promise<{ child: string }> }) {
  const { child: childId } = await params;
  const { child } = await findChild(childId);
  if (!child) notFound();

  const stage = futureStage(child.grade);
  if (stage === 'university') {
    return (
      <ComingSoon
        title="Future"
        icon="cap"
        intro={`Where ${child.name} is applying, and what’s still to do.`}
        points={[
          'Live APS score against each course’s requirement',
          'Applications by university, with opening dates and deadlines',
          'The document checklist for each application',
          'NBT dates, and bursaries that match',
        ]}
      />
    );
  }
  return (
    <ComingSoon
      title="Future"
      icon="cap"
      intro={`No pressure: a light look at what ${child.name} enjoys and where it could lead.`}
      points={
        stage === 'subject_choice'
          ? [
              'Which Grade 10 subjects keep which university courses open',
              `The interests ${child.name} shared, revisited each year`,
            ]
          : [
              `The interests ${child.name} shared, revisited each year`,
              'Possible pathways, without any pressure to choose yet',
            ]
      }
    />
  );
}
