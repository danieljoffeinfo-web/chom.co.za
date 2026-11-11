import { NextResponse } from 'next/server';

/** Per person, per request: never cached. */
export const noStore = { 'Cache-Control': 'private, no-store' };

export const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** A due date picked by a student (a day, no time) is due at the end of that day in SA. */
export function endOfDaySast(day: string): string {
  return `${day}T23:59:00+02:00`;
}

/**
 * Refuses a write that comes from another site. Browsers send Origin on POST, PATCH
 * and DELETE; the session cookie alone must not be enough to change a student's tasks.
 */
export function crossSite(request: Request): NextResponse | null {
  const origin = request.headers.get('origin');
  const host = request.headers.get('host');
  if (!origin || !host) return null;
  try {
    if (new URL(origin).host === host) return null;
  } catch {
    // Fall through: an unparseable Origin is refused.
  }
  return NextResponse.json({ error: 'cross_site' }, { status: 403, headers: noStore });
}

export type TaskRow = {
  id: string;
  kind: 'assigned' | 'personal';
  title: string;
  notes: string | null;
  due_at: string | null;
  subjects: { name: string } | null;
  creator: { full_name: string; preferred_name: string | null } | null;
  task_attachments: {
    id: string;
    file_name: string;
    size_bytes: number;
    content_type: string | null;
  }[];
};

export const TASK_SELECT =
  'id, kind, title, notes, due_at, subjects(name), creator:profiles!tasks_created_by_fkey(full_name, preferred_name), task_attachments(id, file_name, size_bytes, content_type)';

/** The shape the student dashboard reads. */
export function toStudentTask(row: TaskRow, done: boolean) {
  return {
    id: row.id,
    kind: row.kind,
    title: row.title,
    notes: row.notes,
    dueAt: row.due_at,
    subject: row.subjects?.name ?? null,
    teacher:
      row.kind === 'assigned' && row.creator
        ? (row.creator.preferred_name ?? row.creator.full_name)
        : null,
    attachments: row.task_attachments.map((a) => ({
      id: a.id,
      name: a.file_name,
      size: a.size_bytes,
      type: a.content_type,
    })),
    done,
  };
}
