import Link from 'next/link';

import { Icon } from '@chom/dashboard';
import { currentStaff } from '@/lib/current-staff';
import { createClient } from '@/lib/supabase/server';
import { loadSetTasks } from '@/lib/tasks';

import { ClassCards, NoClasses } from './class-cards';

export const metadata = { title: 'Today · Chom Staff' };

function greeting(hour: number) {
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
}

/** Today: the first page a teacher sees. The timetable and work due arrive later. */
export default async function Today() {
  const staff = await currentStaff();
  if (!staff) return null; // The layout already sent them to /start.
  const drawnAt = new Date().getTime();
  const tasks = staff.classes.length ? await loadSetTasks(await createClient(), staff) : [];

  const now = new Date();
  const zone = 'Africa/Johannesburg';
  const hour = Number(
    new Intl.DateTimeFormat('en-ZA', { hour: 'numeric', hourCycle: 'h23', timeZone: zone }).format(
      now,
    ),
  );
  const date = new Intl.DateTimeFormat('en-ZA', {
    weekday: 'long',
    day: 'numeric',
    month: 'long',
    year: 'numeric',
    timeZone: zone,
  }).format(now);

  const classCount = new Set(staff.classes.map((c) => c.classId)).size;
  const learners = staff.classes.reduce((sum, c) => sum + c.learners, 0);
  const onboarded = staff.classes.reduce((sum, c) => sum + c.onboarded, 0);

  return (
    <div className="cd">
      <div className="cd-top">
        <header className="cd-hero">
          <span className="cd-label">{date}</span>
          <h1 className="cd-title">
            {greeting(hour)}, {staff.name}.
          </h1>
          <p className="cd-lede">
            You teach{' '}
            <strong>
              {staff.classes.length === 1 ? '1 subject' : `${staff.classes.length} subjects`}
            </strong>{' '}
            across {classCount === 1 ? '1 class' : `${classCount} classes`} this year.
          </p>
        </header>
        <section className="cd-stats" aria-label="Your classes in numbers">
          <div className="cd-stat">
            <span className="cd-num">{learners}</span>
            <strong>Learner places</strong>
            <small>Across the subjects you teach</small>
          </div>
          <div className="cd-stat">
            <span className="cd-num">{onboarded}</span>
            <strong>Set up Chom</strong>
            <small>Finished their study setup</small>
          </div>
        </section>
      </div>

      <section className="cd-section" aria-labelledby="classes-title">
        <div className="cd-head">
          <div>
            <span className="cd-label">My Classes</span>
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
