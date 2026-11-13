import { Icon } from '@chom/dashboard';
import { notFound } from 'next/navigation';

import { findChild } from '@/lib/parent/current-parent';

import { SubjectList } from '../subject-list';

export const metadata = { title: 'Academics · Chom Parent' };

/** Academics (spec §5.2, §5.3): subjects now; marks, study time and attendance next. */
export default async function Academics({ params }: { params: Promise<{ child: string }> }) {
  const { child: childId } = await params;
  const { child } = await findChild(childId);
  if (!child) notFound();

  return (
    <>
      <header className="view-header">
        <div>
          <h1>Academics</h1>
          <p>
            {child.name}’s subjects{child.yearLabel ? ` for ${child.yearLabel}` : ''}, their
            teachers and the targets {child.name} set.
          </p>
        </div>
      </header>

      <SubjectList subjects={child.subjects} childName={child.name} />

      <div className="parent-coming">
        <section className="content-card coming-card tone-coral">
          <span className="coming-card-icon" aria-hidden="true">
            <Icon name="chart" />
          </span>
          <h2>Marks and readiness</h2>
          <p>
            Each subject’s marks and trend, how ready {child.name} is for upcoming tests, and the
            topics to work on.
          </p>
          <span className="soon-pill">Coming soon</span>
        </section>
        <section className="content-card coming-card tone-sky">
          <span className="coming-card-icon" aria-hidden="true">
            <Icon name="clock" />
          </span>
          <h2>Study time</h2>
          <p>
            Time spent studying on Chom each day and week, by subject and time of day, compared only
            with {child.name}’s own usual.
          </p>
          <span className="soon-pill">Coming soon</span>
        </section>
        <section className="content-card coming-card tone-mint">
          <span className="coming-card-icon" aria-hidden="true">
            <Icon name="check" />
          </span>
          <h2>Attendance</h2>
          <p>
            Days present, absences and late arrivals, and a same-day alert if {child.name} is marked
            absent, so you can give a reason straight away.
          </p>
          <span className="soon-pill">Coming soon</span>
        </section>
      </div>
    </>
  );
}
