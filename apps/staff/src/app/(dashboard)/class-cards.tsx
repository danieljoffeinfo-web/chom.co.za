import { Icon } from '@chom/dashboard';
import { gradeLabel, subjectInitials, type TeachingClass } from '@/lib/staff';

/** One card per subject taught to a class, styled like the learner's "Your classes". */
export function ClassCards({ classes }: { classes: TeachingClass[] }) {
  return (
    <div className="cd-classes">
      {classes.map((c) => (
        <div className="cd-class" key={c.classSubjectId}>
          <span className="cd-class-top">
            <span className="cd-avatar" aria-hidden="true">
              {subjectInitials(c.subjectName)}
            </span>
          </span>
          <span>
            <strong>{c.subjectName}</strong>
            <small>
              {c.className} · {gradeLabel(c.grade)}
            </small>
          </span>
        </div>
      ))}
    </div>
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
