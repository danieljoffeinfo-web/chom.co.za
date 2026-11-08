'use client';

import { useRouter } from 'next/navigation';
import { type FormEvent, useMemo, useRef, useState } from 'react';
import * as tus from 'tus-js-client';

import { Icon } from '@/components/icon';
import { gradeLabel } from '@/lib/staff';
import { createClient } from '@/lib/supabase/browser';
import { supabaseEnv } from '@/lib/supabase/env';
import {
  ACCEPT,
  TASK_FILES_BUCKET,
  contentTypeFor,
  fileProblem,
  formatBytes,
  isVideo,
  storagePath,
} from '@/lib/task-files';

import { addAttachment, createTask, publishTask } from '../actions';
import styles from '../set-work.module.css';

export type ClassChoice = {
  classSubjectId: string;
  className: string;
  grade: number;
  subjectName: string;
  learners: number;
};

type Picked = {
  key: string;
  file: File;
  progress: number;
  state: 'waiting' | 'uploading' | 'done' | 'failed';
};

/**
 * Supabase serves resumable uploads fastest from the storage host itself:
 * https://<ref>.supabase.co → https://<ref>.storage.supabase.co.
 */
function uploadEndpoint(url: string): string {
  const base = url.replace(/\/$/, '');
  return `${base.replace(/^(https:\/\/[^.]+)\.supabase\.co$/, '$1.storage.supabase.co')}/storage/v1/upload/resumable`;
}

/** Uploads one file in 6 MB pieces, picking up where it left off if the connection drops. */
function upload(
  file: File,
  path: string,
  contentType: string,
  accessToken: string,
  onProgress: (fraction: number) => void,
): Promise<void> {
  const { url } = supabaseEnv();
  return new Promise((resolve, reject) => {
    const job = new tus.Upload(file, {
      endpoint: uploadEndpoint(url),
      retryDelays: [0, 2000, 5000, 10000, 20000],
      headers: { authorization: `Bearer ${accessToken}`, 'x-upsert': 'false' },
      uploadDataDuringCreation: true,
      removeFingerprintOnSuccess: true,
      // Supabase requires exactly 6 MB pieces.
      chunkSize: 6 * 1024 * 1024,
      metadata: {
        bucketName: TASK_FILES_BUCKET,
        objectName: path,
        contentType,
        cacheControl: '3600',
      },
      onProgress: (sent, total) => onProgress(total ? sent / total : 0),
      onSuccess: () => resolve(),
      onError: (error) => reject(error),
    });
    job.start();
  });
}

function defaultDueDate(): string {
  const d = new Date(Date.now() + 2 * 24 * 60 * 60 * 1000);
  return d.toLocaleDateString('en-CA', { timeZone: 'Africa/Johannesburg' });
}

export function TaskForm({ classes }: { classes: ClassChoice[] }) {
  const router = useRouter();
  const [title, setTitle] = useState('');
  const [notes, setNotes] = useState('');
  const [dueOn, setDueOn] = useState(defaultDueDate);
  const [dueTime, setDueTime] = useState('08:00');
  const [chosen, setChosen] = useState<string[]>([]);
  const [files, setFiles] = useState<Picked[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState<null | 'saving' | 'uploading' | 'sending'>(null);
  const [dragging, setDragging] = useState(false);
  const fileInput = useRef<HTMLInputElement>(null);
  // Once saved, a retry reuses the task and only uploads what didn't make it.
  const [saved, setSaved] = useState<{ taskId: string; schoolId: string } | null>(null);

  const chosenSubject = classes.find((c) => chosen.includes(c.classSubjectId))?.subjectName;
  const bySubject = useMemo(() => {
    const groups = new Map<string, ClassChoice[]>();
    for (const c of classes) groups.set(c.subjectName, [...(groups.get(c.subjectName) ?? []), c]);
    return [...groups.entries()];
  }, [classes]);

  function toggleClass(id: string) {
    setChosen((now) => (now.includes(id) ? now.filter((x) => x !== id) : [...now, id]));
  }

  function addFiles(list: FileList | null) {
    if (!list) return;
    const problems: string[] = [];
    const added: Picked[] = [];
    for (const file of Array.from(list)) {
      const problem = fileProblem(file);
      if (problem) problems.push(problem);
      else
        added.push({
          key: `${file.name}-${file.size}-${file.lastModified}`,
          file,
          progress: 0,
          state: 'waiting',
        });
    }
    setFiles((now) => [...now, ...added.filter((a) => !now.some((n) => n.key === a.key))]);
    setError(problems.length ? problems.join(' ') : null);
  }

  function update(key: string, change: Partial<Picked>) {
    setFiles((now) => now.map((f) => (f.key === key ? { ...f, ...change } : f)));
  }

  async function submit(event: FormEvent) {
    event.preventDefault();
    if (busy) return;
    setError(null);
    if (!chosen.length) {
      setError('Choose at least one class.');
      return;
    }

    try {
      let task = saved;
      if (!task) {
        setBusy('saving');
        const result = await createTask({ title, notes, dueOn, dueTime, classSubjectIds: chosen });
        if (!result.ok) {
          setError(result.error);
          return;
        }
        task = { taskId: result.taskId, schoolId: result.schoolId };
        setSaved(task);
      }
      const { taskId, schoolId } = task;

      const toUpload = files.filter((f) => f.state !== 'done');
      if (toUpload.length) {
        setBusy('uploading');
        const { data } = await createClient().auth.getSession();
        const token = data.session?.access_token;
        if (!token) {
          setError('Your sign-in has expired. Please sign in again.');
          return;
        }
        let failed = 0;
        // Two at a time: quick on a good line, gentle on a school's shared Wi-Fi.
        const queue = [...toUpload];
        const worker = async () => {
          for (let next = queue.shift(); next; next = queue.shift()) {
            const item = next;
            const type = contentTypeFor(item.file) ?? 'application/octet-stream';
            const path = storagePath(schoolId, taskId, item.file.name, crypto.randomUUID());
            update(item.key, { state: 'uploading', progress: 0 });
            try {
              await upload(item.file, path, type, token, (p) => update(item.key, { progress: p }));
              const recorded = await addAttachment({
                taskId,
                path,
                name: item.file.name,
                size: item.file.size,
                type,
              });
              if (!recorded.ok) throw new Error(recorded.error);
              update(item.key, { state: 'done', progress: 1 });
            } catch {
              failed += 1;
              update(item.key, { state: 'failed' });
            }
          }
        };
        await Promise.all([worker(), worker()]);
        if (failed) {
          setError(
            `${failed === 1 ? 'One file' : `${failed} files`} didn’t upload. Your task is saved but not sent yet: check your connection and press “Set task” again to retry, or remove the file.`,
          );
          return;
        }
      }

      setBusy('sending');
      const sent = await publishTask({ taskId, classSubjectIds: chosen });
      if (!sent.ok) {
        setError(sent.error);
        return;
      }
      router.push(`/set-work/${taskId}`);
      router.refresh();
    } catch {
      setError('Something went wrong. Check your connection and try again.');
    } finally {
      setBusy(null);
    }
  }

  const locked = busy !== null || saved !== null;

  return (
    <form className={`panel ${styles.form}`} onSubmit={submit}>
      <div className="field">
        <label htmlFor="title">Task</label>
        <input
          id="title"
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          placeholder="e.g. Exercise 6.3: trigonometric identities"
          maxLength={200}
          required
          disabled={locked}
          autoComplete="off"
        />
      </div>

      <div className="field">
        <label htmlFor="notes">Notes for your learners</label>
        <textarea
          id="notes"
          value={notes}
          onChange={(e) => setNotes(e.target.value)}
          placeholder="What to do, which pages, how to hand it in…"
          maxLength={20000}
          disabled={locked}
        />
      </div>

      <div className="form-row">
        <div className="field">
          <label htmlFor="due-on">Due date</label>
          <input
            id="due-on"
            type="date"
            value={dueOn}
            onChange={(e) => setDueOn(e.target.value)}
            required
            disabled={locked}
          />
        </div>
        <div className="field">
          <label htmlFor="due-time">Time</label>
          <input
            id="due-time"
            type="time"
            value={dueTime}
            onChange={(e) => setDueTime(e.target.value)}
            required
            disabled={locked}
          />
        </div>
      </div>

      <fieldset className={styles.fieldset}>
        <legend className={styles.legend}>Classes</legend>
        {bySubject.map(([subject, list]) => (
          <div key={subject} className={styles.classGroup}>
            <p className={styles.subjectName}>{subject}</p>
            <div className={styles.classes}>
              {list.map((c) => (
                <label className={styles.classOption} key={c.classSubjectId}>
                  <input
                    type="checkbox"
                    checked={chosen.includes(c.classSubjectId)}
                    onChange={() => toggleClass(c.classSubjectId)}
                    disabled={
                      locked || (chosenSubject !== undefined && chosenSubject !== c.subjectName)
                    }
                  />
                  <span>
                    {c.className}
                    <small>
                      {gradeLabel(c.grade)} · {c.learners} learners
                    </small>
                  </span>
                </label>
              ))}
            </div>
          </div>
        ))}
        <p className={styles.hint}>A task is for one subject. Pick one class or several.</p>
      </fieldset>

      <div className="field">
        <label htmlFor="files">Files</label>
        <button
          type="button"
          disabled={busy !== null}
          className={`${styles.drop} ${dragging ? styles.dropActive : ''}`}
          onClick={() => fileInput.current?.click()}
          onDragOver={(e) => {
            e.preventDefault();
            setDragging(true);
          }}
          onDragLeave={() => setDragging(false)}
          onDrop={(e) => {
            e.preventDefault();
            setDragging(false);
            if (!busy) addFiles(e.dataTransfer.files);
          }}
        >
          <Icon name="file" />
          <span>
            <strong>Drop files here</strong> or click to choose
          </span>
          <span className={styles.hint}>
            PDF, Word, PowerPoint, Excel, images, audio, video or zip · up to 300 MB each
          </span>
        </button>
        <input
          ref={fileInput}
          id="files"
          type="file"
          multiple
          accept={ACCEPT}
          hidden
          onChange={(e) => {
            addFiles(e.target.files);
            e.target.value = '';
          }}
        />
        {files.some((f) => isVideo(f.file)) && (
          <p className={styles.tip}>
            Tip: a YouTube or Teams link in the notes saves your learners’ data, and uploads faster
            than a video file.
          </p>
        )}
        {files.length > 0 && (
          <ul className={styles.files}>
            {files.map((f) => (
              <li className={styles.file} key={f.key}>
                <span className={styles.fileName}>
                  {f.file.name} <span className="muted">· {formatBytes(f.file.size)}</span>
                </span>
                {f.state === 'done' ? (
                  <span className="muted">Uploaded</span>
                ) : f.state === 'uploading' ? (
                  <span className="muted">{Math.round(f.progress * 100)}%</span>
                ) : (
                  <button
                    type="button"
                    className="text-button"
                    onClick={() => setFiles((now) => now.filter((x) => x.key !== f.key))}
                    disabled={busy !== null}
                  >
                    {f.state === 'failed' ? 'Didn’t upload · Remove' : 'Remove'}
                  </button>
                )}
                {(f.state === 'uploading' || f.state === 'done') && (
                  <span className={styles.track}>
                    <i style={{ width: `${Math.round(f.progress * 100)}%` }} />
                  </span>
                )}
              </li>
            ))}
          </ul>
        )}
      </div>

      {error && (
        <p className={styles.error} role="alert">
          {error}
        </p>
      )}

      <div className="form-actions">
        <button
          className="button secondary"
          type="button"
          onClick={() => router.push('/set-work')}
          disabled={busy !== null}
        >
          Cancel
        </button>
        <button className="button" type="submit" disabled={busy !== null}>
          {busy === 'saving'
            ? 'Saving…'
            : busy === 'uploading'
              ? 'Uploading…'
              : busy === 'sending'
                ? 'Sending…'
                : 'Set task'}
        </button>
      </div>
    </form>
  );
}
