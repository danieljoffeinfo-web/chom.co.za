import { Icon } from '@chom/dashboard';
import Link from 'next/link';
import { notFound } from 'next/navigation';

import { findChild } from '@/lib/parent/current-parent';
import { gradeLabel } from '@/lib/parent/parent';
import { SESSION_LENGTHS, STUDY_METHODS, STUDY_TIMES } from '@/lib/student';

import { SubjectList } from './subject-list';

export const metadata = { title: 'Home · Chom Parent' };

const ZONE = 'Africa/Johannesburg';

function greeting(hour: number) {
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
}

const labels = <T extends string>(options: { value: T; label: string }[], values: T[]) =>
  options.filter((o) => values.includes(o.value)).map((o) => o.label);

/**
 * Home (spec §5.1): the 30-second view. Is my child okay, what's coming up, what can I
 * do. Attendance, study time, readiness and the weekly summary join this page as
 * their slices are built; until then it shows what Chom already knows.
 */
export default async function ChildHome({ params }: { params: Promise<{ child: string }> }) {
  const { child: childId } = await params;
  const { parent, child } = await findChild(childId);
  if (!parent || !child) notFound();

  const now = new Date();
  const hour = Number(
    new Intl.DateTimeFormat('en-ZA', { hour: 'numeric', hourCycle: 'h23', timeZone: ZONE }).format(
      now,
    ),
  );
  const date = new Intl.DateTimeFormat('en-ZA', {
    weekday: 'long',
    day: 'numeric',
    month: 'long',
    timeZone: ZONE,
  }).format(now);

  const targets = child.subjects.filter((s) => s.targetPercent != null).length;
  const focus = child.subjects.filter((s) => s.isFocus);
  const where = [gradeLabel(child.grade), child.classes.join(', ')].filter(Boolean).join(', ');
  const onboarded = Boolean(child.study?.onboardingCompletedAt);

  return (
    <div className="cd">
      <div className="cd-top">
        <header className="cd-hero">
          <span className="cd-label">{date}</span>
          <h1 className="cd-title">
            {greeting(hour)}, {parent.name}.
          </h1>
          <p className="cd-lede">
            <strong>{child.name}</strong> is in {where || 'school'} at {child.schoolName}.{' '}
            {onboarded
              ? `${child.name} has set up Chom and chosen what to work towards.`
              : `${child.name} hasn’t finished setting up Chom yet.`}
          </p>
        </header>
        <section className="cd-stats" aria-label={`${child.name} in numbers`}>
          <div className="cd-stat">
            <span className="cd-num">{child.subjects.length}</span>
            <strong>Subjects</strong>
            <small>This year</small>
          </div>
          <div className="cd-stat">
            <span className="cd-num">
              {targets}
              <small className="cd-of">/{child.subjects.length}</small>
            </span>
            <strong>Targets set</strong>
            <small>Chosen by {child.name}</small>
          </div>
          <div className="cd-stat">
            <span className="cd-num">{focus.length}</span>
            <strong>Focus subjects</strong>
            <small>{focus.length ? focus.map((s) => s.name).join(', ') : 'None chosen yet'}</small>
          </div>
        </section>
      </div>

      <section className="cd-section" aria-labelledby="week-title">
        <div className="cd-head">
          <div>
            <span className="cd-label">What’s coming up</span>
            <h2 id="week-title">This week</h2>
          </div>
        </div>
        <section className="panel">
          <div className="empty-message">
            <Icon name="calendar" />
            <p>
              Tests, homework, training, fixtures and school events will show here, with anything
              you need to do, like confirming {child.name} can play or signing a slip.
            </p>
          </div>
        </section>
      </section>

      <section className="cd-section" aria-labelledby="subjects-title">
        <div className="cd-head">
          <div>
            <span className="cd-label">Academics</span>
            <h2 id="subjects-title">How {child.name} is doing</h2>
          </div>
          <Link className="text-button" href={`/parent/${child.id}/academics`}>
            All subjects <Icon name="arrow" small />
          </Link>
        </div>
        <SubjectList subjects={child.subjects} childName={child.name} />
      </section>

      {child.study && onboarded && (
        <section className="cd-section" aria-labelledby="study-title">
          <div className="cd-head">
            <div>
              <span className="cd-label">Study habits</span>
              <h2 id="study-title">How {child.name} likes to study</h2>
            </div>
          </div>
          <section className="content-card study-facts">
            <dl>
              <div>
                <dt>In one go</dt>
                <dd>
                  {SESSION_LENGTHS.find((o) => o.value === child.study?.sessionLength)?.label ??
                    '—'}
                </dd>
              </div>
              <div>
                <dt>How</dt>
                <dd>{labels(STUDY_METHODS, child.study.studyMethods).join(', ') || '—'}</dd>
              </div>
              <div>
                <dt>When</dt>
                <dd>{labels(STUDY_TIMES, child.study.studyTimes).join(', ') || '—'}</dd>
              </div>
            </dl>
          </section>
        </section>
      )}

      <div className="notice">
        Attendance, study time on Chom, marks and a short weekly summary will appear here as
        {` ${child.schoolName}`} switches them on. We’ll only show {child.name} against their own
        goals, never against classmates.
      </div>
    </div>
  );
}
