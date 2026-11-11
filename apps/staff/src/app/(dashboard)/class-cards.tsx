import Link from 'next/link';

import { Icon } from '@chom/dashboard';
import { gradeLabel, subjectInitials, type TeachingClass } from '@/lib/staff';

/** The subjects a teacher takes, one row each; a row opens a new task for that class. */
export function ClassCards({ classes }: { classes: TeachingClass[] }) {
  return (
    <ul className="class-list">
      {classes.map((c) => (
        <li key={c.classSubjectId}>
          <Link
            className="class-row"
            href={`/set-work/new?class=${encodeURIComponent(c.classSubjectId)}`}
          >
            <span className="cd-avatar" aria-hidden="true">
              {subjectInitials(c.subjectName)}
            </span>
            <span className="class-row-text">
              <strong>{c.subjectName}</strong>
              <small>
                {c.className} · {gradeLabel(c.grade)}
              </small>
            </span>
            <span className="class-row-go">
              Set work <Icon name="chevron" small />
            </span>
          </Link>
        </li>
      ))}
    </ul>
  );
}

export function NoClasses() {
  return (
    <section className="panel">
      <div className="empty-message">
        <Icon name="school" />
        <h2>No classes yet</h2>
        <p>
          Your school admin allocates classes to teachers. Once you’re allocated a class for this
          year, it appears here.
        </p>
      </div>
    </section>
  );
}
