import { SubjectBadge } from '@chom/dashboard';

import type { ChildSubject } from '@/lib/parent/parent';

/**
 * One row per subject. Status bands (on track / watch / needs attention) arrive with
 * marks (spec §5.1); until then each row says what's known: teacher, target, focus.
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
    <section className="panel">
      <ul className="task-list subject-rows">
        {subjects.map((s) => (
          <li className="task-row" key={s.id}>
            <SubjectBadge name={s.name} />
            <span className="task-content">
              <span className="task-name">
                {s.name}
                {s.isFocus && <em className="focus-tag">Focus</em>}
              </span>
              <span className="task-sub">
                {s.teachers.length ? s.teachers.join(', ') : 'Teacher not set yet'}
              </span>
            </span>
            <span className="subject-figures">
              <span className="band none">No marks yet</span>
              <small>
                {s.targetPercent != null ? `Aiming for ${s.targetPercent}%` : 'No target set'}
              </small>
            </span>
          </li>
        ))}
      </ul>
    </section>
  );
}
