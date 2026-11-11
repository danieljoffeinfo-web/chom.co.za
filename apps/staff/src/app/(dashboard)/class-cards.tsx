import Link from 'next/link';

import { Icon, subjectIcon } from '@chom/dashboard';
import { gradeLabel, type TeachingClass } from '@/lib/staff';
import type { SetTask } from '@/lib/tasks';

/** Badge tints. A subject starts from a colour picked by its name, and moves along if
 * another subject in the same class already has it, so a class never repeats one. */
const TINTS = [
  '#3b6fd8',
  '#d9682b',
  '#2f9a6a',
  '#b0489c',
  '#c99a16',
  '#6a5acd',
  '#1f8fa3',
  '#c2414b',
];

function startTint(name: string): number {
  let h = 0;
  for (const ch of name) h = (h * 31 + ch.charCodeAt(0)) >>> 0;
  return h % TINTS.length;
}

function tintsFor(names: string[]): Map<string, string> {
  const used = new Set<number>();
  const out = new Map<string, string>();
  for (const name of names) {
    let i = startTint(name);
    for (let step = 0; step < TINTS.length && used.has(i); step++) i = (i + 1) % TINTS.length;
    used.add(i);
    if (used.size === TINTS.length) used.clear();
    out.set(name, TINTS[i]!);
  }
  return out;
}

const SHORT_DAY = new Intl.DateTimeFormat('en-ZA', {
  weekday: 'short',
  day: 'numeric',
  month: 'short',
  timeZone: 'Africa/Johannesburg',
});

/** "2 due · next Thu 12 Nov", or null when nothing is waiting on this class. */
function workStatus(classSubjectId: string, tasks: SetTask[], now: number) {
  const upcoming = tasks
    .filter((t) => t.dueAt && Date.parse(t.dueAt) >= now)
    .filter((t) => t.classes.some((c) => c.classSubjectId === classSubjectId))
    .sort((a, b) => Date.parse(a.dueAt) - Date.parse(b.dueAt));
  const next = upcoming[0];
  if (!next) return null;
  return { count: upcoming.length, next: SHORT_DAY.format(new Date(next.dueAt)) };
}

/**
 * The subjects a teacher takes, grouped by class (10D, 11A…), one row per subject with
 * what work is due. A row opens a new task for that class.
 */
export function ClassCards({
  classes,
  tasks,
  now,
}: {
  classes: TeachingClass[];
  tasks: SetTask[];
  /** When the page was drawn, in ms, to tell upcoming work from past. */
  now: number;
}) {
  const groups = new Map<string, TeachingClass[]>();
  for (const c of classes) groups.set(c.classId, [...(groups.get(c.classId) ?? []), c]);
  const ordered = [...groups.values()].sort(
    (a, b) => a[0]!.grade - b[0]!.grade || a[0]!.className.localeCompare(b[0]!.className),
  );

  return (
    <div className="class-groups">
      {ordered.map((group) => {
        const first = group[0]!;
        const subjects = [...group].sort((a, b) => a.subjectName.localeCompare(b.subjectName));
        const tints = tintsFor(subjects.map((c) => c.subjectName));
        return (
          <section className="class-group" key={first.classId} aria-label={first.className}>
            <header className="class-group-head">
              <strong>{first.className}</strong>
              <span>
                {gradeLabel(first.grade)} ·{' '}
                {subjects.length === 1 ? '1 subject' : `${subjects.length} subjects`}
              </span>
            </header>
            <ul className="class-list">
              {subjects.map((c) => {
                const status = workStatus(c.classSubjectId, tasks, now);
                return (
                  <li key={c.classSubjectId}>
                    <Link
                      className="class-row"
                      href={`/set-work/new?class=${encodeURIComponent(c.classSubjectId)}`}
                      title={`Set work for ${c.subjectName}, ${c.className}`}
                    >
                      <span
                        className="class-badge"
                        aria-hidden="true"
                        style={{ '--tint': tints.get(c.subjectName) } as React.CSSProperties}
                      >
                        <Icon name={subjectIcon(c.subjectName)} />
                      </span>
                      <span className="class-row-name">{c.subjectName}</span>
                      <span className={status ? 'class-row-status due' : 'class-row-status'}>
                        {status ? (
                          <>
                            <b>{status.count} due</b> · next {status.next}
                          </>
                        ) : (
                          'No work set'
                        )}
                      </span>
                      <span className="class-row-go">
                        <span className="class-row-go-label">Set work</span>
                        <Icon name="chevron" small />
                      </span>
                    </Link>
                  </li>
                );
              })}
            </ul>
          </section>
        );
      })}
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
