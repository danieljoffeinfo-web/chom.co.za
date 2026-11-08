'use client';

import { useState, useTransition } from 'react';

import { deleteTask } from '../actions';

/** Deletes the task and its files, after a second click to confirm. */
export function DeleteTask({ taskId }: { taskId: string }) {
  const [confirming, setConfirming] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();

  if (!confirming) {
    return (
      <button className="button secondary" type="button" onClick={() => setConfirming(true)}>
        Delete task
      </button>
    );
  }
  return (
    <div
      role="group"
      aria-label="Confirm delete"
      style={{ display: 'flex', gap: 9, alignItems: 'center', flexWrap: 'wrap' }}
    >
      <span className="muted">Delete it for every class, with its files?</span>
      <button
        className="button secondary"
        type="button"
        onClick={() => setConfirming(false)}
        disabled={pending}
      >
        Keep it
      </button>
      <button
        className="button"
        type="button"
        disabled={pending}
        onClick={() =>
          startTransition(async () => {
            const result = await deleteTask(taskId);
            if (result && !result.ok) setError(result.error);
          })
        }
      >
        {pending ? 'Deleting…' : 'Delete'}
      </button>
      {error && (
        <span role="alert" className="muted">
          {error}
        </span>
      )}
    </div>
  );
}
