import type { CSSProperties } from 'react';

import { SubjectBadge, subjectStyle } from '@chom/dashboard';

import type { ChildSubject } from '@/lib/parent/parent';

/**
 * One card per subject, tinted in the subject's colour, with the goal the child set as a
 * ring. Status bands (on track / watch / needs attention) arrive with marks (spec §5.1);
 * until then each card says what's known: teacher, target, focus.
 */
export function SubjectList({
  subjects,
  childName,
}: {
  subjects: ChildSubject[];
  childName: string;
}) {
  if (!subjects.length) {
    return (
      <section className="panel">
        <div className="empty-message">
          <h2>No subjects yet</h2>
          <p>{childName}’s subjects appear here once the school has set up their classes.</p>
        </div>
      </section>
    );
  }

  return (
    <ul className="subject-cards">
      {subjects.map((s) => (
        <li className={`subject-card subject-tint ${subjectStyle(s.name).color}`} key={s.id}>
          <div className="subject-card-top">
            <SubjectBadge name={s.name} />
            {s.isFocus && <em className="focus-tag">Focus</em>}
          </div>
          <strong className="subject-card-name">{s.name}</strong>
          <span className="subject-card-teacher">
            {s.teachers.length ? s.teachers.join(', ') : 'Teacher not set yet'}
          </span>
          <div className="subject-card-foot">
            <span
              className={s.targetPercent != null ? 'goal-ring' : 'goal-ring empty'}
              style={{ '--v': `${s.targetPercent ?? 0}%` } as CSSProperties}
              aria-hidden="true"
            >
              {s.targetPercent ?? '–'}
            </span>
            <span className="subject-card-goal">
              <small>Goal</small>
              <b>{s.targetPercent != null ? `Aiming for ${s.targetPercent}%` : 'No target set'}</b>
            </span>
            <span className="band none">No marks yet</span>
          </div>
        </li>
      ))}
    </ul>
  );
}
