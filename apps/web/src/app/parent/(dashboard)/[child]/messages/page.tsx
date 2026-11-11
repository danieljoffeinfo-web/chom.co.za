import { ComingSoon } from '@chom/dashboard';
import { notFound } from 'next/navigation';

import { findChild } from '@/lib/parent/current-parent';

export const metadata = { title: 'Messages · Chom Parent' };

export default async function Messages({ params }: { params: Promise<{ child: string }> }) {
  const { child: childId } = await params;
  const { child } = await findChild(childId);
  if (!child) notFound();

  return (
    <ComingSoon
      title="Messages"
      icon="message"
      intro={`News from ${child.schoolName}, and a direct line to ${child.name}’s teachers.`}
      points={[
        'School announcements in one feed',
        'Message a teacher, within their office hours',
        'Book a parent-teacher meeting from published slots',
      ]}
    />
  );
}
