import { Icon } from '@chom/dashboard';
import Link from 'next/link';
import type { CSSProperties } from 'react';
import { notFound } from 'next/navigation';

import { findChild } from '@/lib/parent/current-parent';
import { gradeLabel } from '@/lib/parent/parent';
import { SESSION_LENGTHS, STUDY_METHODS, STUDY_TIMES } from '@/lib/student';

import { SubjectList } from './subject-list';

export const metadata = { title: 'Home · Chom Parent' };

const ZONE = 'Africa/Johannesburg';

/** "Maths", "Maths and English", "Maths, English and History". */
const listOf = (names: string[]) =>
  names.length < 2 ? (names[0] ?? '') : `${names.slice(0, -1).join(', ')} and ${names.at(-1)}`;

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
  const weekday = new Intl.DateTimeFormat('en-ZA', { weekday: 'long', timeZone: ZONE }).format(now);
  const date = new Intl.DateTimeFormat('en-ZA', {
    day: 'numeric',
    month: 'long',
    timeZone: ZONE,
  }).format(now);

  const targets = child.subjects.filter((s) => s.targetPercent != null).length;
  const focus = child.subjects.filter((s) => s.isFocus);
  const where = [gradeLabel(child.grade), child.classes.join(', ')].filter(Boolean).join(', ');
  const onboarded = Boolean(child.study?.onboardingCompletedAt);
  // About the child, not a greeting for the parent: the one thing Chom knows today.
  // shortcut: parents can't read tasks yet (RLS), so no "3 tasks due today"; add it when they can.
  const headline = !onboarded
    ? `${child.name} hasn’t set up Chom yet.`
    : focus.length
      ? `${child.name} is focusing on ${listOf(focus.map((s) => s.name))}.`
      : `${child.name} has set ${targets} of ${child.subjects.length} targets.`;

  return (
    <div className="cd">
      <div className="cd-top">
        <header className="cd-hero">
          <span className="cd-label">
            {weekday} {date}
          </span>
          <h1 className="cd-title">{headline}</h1>
          <p className="cd-lede">
            {child.name} is in <strong>{where || 'school'}</strong> at {child.schoolName}.{' '}
            {onboarded
              ? 'Marks and what’s due will show here as the school switches them on.'
              : 'Once they do, their targets and how they like to study show here.'}
          </p>
        </header>
        <section className="cd-stats" aria-label={`${child.name} in numbers`}>
          <div className="cd-stat">
            <span className="cd-stat-icon" aria-hidden="true">
              <Icon name="book" />
            </span>
            <span className="cd-num">{child.subjects.length}</span>
            <strong>Subjects</strong>
            <small>This year</small>
          </div>
          <div className="cd-stat">
            <span className="cd-stat-icon" aria-hidden="true">
              <Icon name="leaf" />
            </span>
            <span className="cd-num">
              {targets}
              <small className="cd-of">/{child.subjects.length}</small>
            </span>
            <strong>Targets set</strong>
            <small>Chosen by {child.name}</small>
            <span className="cd-meter" aria-hidden="true">
              <i
                style={
                  {
                    '--v': `${child.subjects.length ? (100 * targets) / child.subjects.length : 0}%`,
                  } as CSSProperties
                }
              />
            </span>
          </div>
        </section>
      </div>

      <section className="cd-section tone-sky" aria-labelledby="week-title">
        <div className="cd-head">
          <div>
            <span className="cd-label">What’s coming up</span>
            <h2 id="week-title">This week</h2>
          </div>
        </div>
        <section className="panel">
          <div className="empty-message">
            <Icon name="calendar" />
            <h2>{child.name}’s week, at a glance</h2>
            <p>
              Tests, homework, training, fixtures and school events will show here, with anything
              you need to do, like confirming {child.name} can play or signing a slip.
            </p>
            <ul className="peek-chips" aria-label="Coming to this week">
              <li className="tone-coral">Tests</li>
              <li className="tone-sunflower">Homework</li>
              <li className="tone-mint">Fixtures</li>
              <li className="tone-sky">Events</li>
              <li className="tone-lilac">Slips to sign</li>
            </ul>
          </div>
        </section>
      </section>

      <section className="cd-section tone-lilac" aria-labelledby="subjects-title">
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
        <section className="cd-section tone-mint" aria-labelledby="study-title">
          <div className="cd-head">
            <div>
              <span className="cd-label">Study habits</span>
              <h2 id="study-title">How {child.name} likes to study</h2>
            </div>
          </div>
          <dl className="study-tiles">
            <div className="study-tile tone-coral">
              <dt>
                <Icon name="clock" />
                In one go
              </dt>
              <dd>
                {SESSION_LENGTHS.find((o) => o.value === child.study?.sessionLength)?.label ?? '—'}
              </dd>
            </div>
            <div className="study-tile tone-sky">
              <dt>
                <Icon name="book" />
                How
              </dt>
              <dd>{labels(STUDY_METHODS, child.study.studyMethods).join(', ') || '—'}</dd>
            </div>
            <div className="study-tile tone-sunflower">
              <dt>
                <Icon name="sun" />
                When
              </dt>
              <dd>{labels(STUDY_TIMES, child.study.studyTimes).join(', ') || '—'}</dd>
            </div>
          </dl>
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
