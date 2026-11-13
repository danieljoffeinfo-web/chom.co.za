import Link from 'next/link';
import type { CSSProperties } from 'react';

import { Icon } from '@chom/dashboard';
import { currentStaff } from '@/lib/current-staff';
import { createClient } from '@/lib/supabase/server';
import { loadSetTasks } from '@/lib/tasks';

import { ClassCards, NoClasses } from './class-cards';

export const metadata = { title: 'Home · Chom Staff' };

const ZONE = 'Africa/Johannesburg';
const DAY = 86_400_000;

/** Home: the first page a teacher sees. The headline is the week's work, not a greeting. */
export default async function Home() {
  const staff = await currentStaff();
  if (!staff) return null; // The layout already sent them to /start.
  const now = new Date();
  const drawnAt = now.getTime();
  const tasks = staff.classes.length ? await loadSetTasks(await createClient(), staff) : [];

  const weekday = new Intl.DateTimeFormat('en-ZA', { weekday: 'long', timeZone: ZONE }).format(now);
  const date = new Intl.DateTimeFormat('en-ZA', {
    day: 'numeric',
    month: 'long',
    timeZone: ZONE,
  }).format(now);
  // This week ends at midnight on Sunday, South African time (UTC+2 all year).
  const today = new Intl.DateTimeFormat('en-CA', { timeZone: ZONE }).format(now);
  const daysLeft = (7 - new Date(`${today}T12:00:00Z`).getUTCDay()) % 7;
  const weekEnds = Date.parse(`${today}T00:00:00+02:00`) + (daysLeft + 1) * DAY;

  const upcoming = tasks
    .filter((t) => t.sent && t.dueAt && Date.parse(t.dueAt) >= drawnAt)
    .sort((a, b) => Date.parse(a.dueAt) - Date.parse(b.dueAt));
  const dueThisWeek = upcoming.filter((t) => Date.parse(t.dueAt) < weekEnds).length;
  const next = upcoming[0];
  const nextDay = next
    ? new Intl.DateTimeFormat('en-ZA', {
        weekday: 'short',
        day: 'numeric',
        month: 'short',
        timeZone: ZONE,
      }).format(new Date(next.dueAt))
    : null;

  const classCount = new Set(staff.classes.map((c) => c.classId)).size;
  const learners = staff.classes.reduce((sum, c) => sum + c.learners, 0);
  const onboarded = staff.classes.reduce((sum, c) => sum + c.onboarded, 0);

  const headline = !staff.classes.length
    ? `${staff.name}, your classes aren’t set up yet.`
    : dueThisWeek
      ? `${staff.name}, ${dueThisWeek} ${dueThisWeek === 1 ? 'task' : 'tasks'} due this week.`
      : `${staff.name}, nothing due this week.`;

  return (
    <div className="cd">
      <div className="cd-top">
        <header className="cd-hero">
          <span className="cd-label">
            {weekday} {date}
          </span>
          <h1 className="cd-title">{headline}</h1>
          <p className="cd-lede">
            {next ? (
              <>
                Next due: <strong>{next.title}</strong>
                {next.classes.length
                  ? ` for ${next.classes.map((c) => c.name).join(', ')}`
                  : ''}, {nextDay}.
              </>
            ) : staff.classes.length ? (
              'Set work for a class and what’s due shows here.'
            ) : (
              'Your school admin allocates classes. They show here once you have one.'
            )}
          </p>
        </header>
        <section className="cd-stats" aria-label="Your week in numbers">
          <div className="cd-stat">
            <span className="cd-stat-icon" aria-hidden="true">
              <Icon name="calendar" />
            </span>
            <span className="cd-num">{dueThisWeek}</span>
            <strong>Due this week</strong>
            <small>{classCount === 1 ? 'Across 1 class' : `Across ${classCount} classes`}</small>
          </div>
          <div className="cd-stat">
            <span className="cd-stat-icon" aria-hidden="true">
              <Icon name="user" />
            </span>
            <span className="cd-num">
              {onboarded}
              <small className="cd-of">/{learners}</small>
            </span>
            <strong>Learners on Chom</strong>
            <small>Finished their study setup</small>
            <span className="cd-meter" aria-hidden="true">
              <i
                style={
                  { '--v': `${learners ? (100 * onboarded) / learners : 0}%` } as CSSProperties
                }
              />
            </span>
          </div>
        </section>
      </div>

      <section className="cd-section tone-sky" aria-labelledby="classes-title">
        <div className="cd-head">
          <div>
            <span className="cd-label">My classes</span>
            <h2 id="classes-title">What you teach</h2>
          </div>
          <Link className="text-button" href="/classes">
            All classes <Icon name="arrow" small />
          </Link>
        </div>
        {staff.classes.length ? (
          <ClassCards classes={staff.classes} tasks={tasks} now={drawnAt} />
        ) : (
          <NoClasses />
        )}
      </section>

      <div className="notice">
        Your timetable, work due and learners to check on will appear here once Calendar and Set
        Work are switched on.
      </div>
    </div>
  );
}
