'use client';

import { useActionState, useState, useTransition } from 'react';

import { type ChannelsState, saveChannels, withdrawConsent } from './actions';

export function ChannelsForm({
  initial,
}: {
  initial: { whatsapp: boolean; email: boolean; push: boolean };
}) {
  const [state, action, pending] = useActionState<ChannelsState, FormData>(saveChannels, {
    saved: false,
    error: null,
  });

  const choices = state.choices ?? initial;

  return (
    <form action={action}>
      <label className="switch-row">
        <span>
          <strong>WhatsApp</strong>
          <small>The Sunday summary and urgent alerts</small>
        </span>
        <input type="checkbox" name="whatsapp" defaultChecked={choices.whatsapp} />
      </label>
      <label className="switch-row">
        <span>
          <strong>Email</strong>
          <small>The Sunday summary</small>
        </span>
        <input type="checkbox" name="email" defaultChecked={choices.email} />
      </label>
      <label className="switch-row">
        <span>
          <strong>Notifications in this browser</strong>
          <small>Alerts while you have Chom open</small>
        </span>
        <input type="checkbox" name="push" defaultChecked={choices.push} />
      </label>
      <p className="form-note">
        Absence alerts always reach you, so you know the same day if your child isn’t at school.
      </p>
      <button className="button" type="submit" disabled={pending}>
        {pending ? 'Saving…' : 'Save'}
      </button>
      <span className="form-status" role="status">
        {state.saved && !pending ? 'Saved' : null}
        {state.error}
      </span>
    </form>
  );
}

export function WithdrawButton({
  guardianshipId,
  childName,
}: {
  guardianshipId: string;
  childName: string;
}) {
  const [confirming, setConfirming] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();

  if (!confirming) {
    return (
      <button className="text-button danger" type="button" onClick={() => setConfirming(true)}>
        Withdraw consent
      </button>
    );
  }
  return (
    <div className="withdraw-confirm" role="group" aria-label={`Withdraw consent for ${childName}`}>
      <p>
        You’ll stop seeing {childName}’s marks, attendance and schoolwork straight away, and only
        get school news and events. {childName}’s school will see that you withdrew it.
      </p>
      <div className="withdraw-actions">
        <button
          className="button"
          type="button"
          disabled={pending}
          onClick={() =>
            start(async () => {
              let message: string | null;
              try {
                ({ error: message } = await withdrawConsent(guardianshipId));
              } catch {
                message = 'We couldn’t withdraw your consent. Please try again in a moment.';
              }
              start(() => {
                setError(message);
                if (!message) setConfirming(false);
              });
            })
          }
        >
          {pending ? 'Withdrawing…' : 'Withdraw'}
        </button>
        <button className="button secondary" type="button" onClick={() => setConfirming(false)}>
          Keep my consent
        </button>
      </div>
      {error && (
        <p className="form-error" role="alert">
          {error}
        </p>
      )}
    </div>
  );
}
