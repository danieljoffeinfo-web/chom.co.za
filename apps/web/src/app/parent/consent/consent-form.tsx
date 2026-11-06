'use client';

import { useActionState, useState } from 'react';

import { type ConsentState, recordConsent } from './actions';

/** The agreement tick box and channel choices. Nothing is saved until they agree. */
export function ConsentForm({ version, agreement }: { version: string; agreement: string }) {
  const [state, action, pending] = useActionState<ConsentState, FormData>(recordConsent, {
    error: null,
  });

  // React resets the form after each submit; the defaults put back what they chose.
  const choices = state.choices ?? { whatsapp: true, email: true, push: false, agree: false };

  // Hide an error once they change something; a new result shows again.
  const [dismissed, setDismissed] = useState<ConsentState | null>(null);
  const error = dismissed === state ? null : state.error;

  return (
    <form action={action} className="consent-form" onChange={() => setDismissed(state)}>
      <input type="hidden" name="version" value={version} />

      <fieldset className="consent-channels">
        <legend>How should Chom reach you?</legend>
        <p>Urgent alerts, like an absence, and your Sunday summary. You can change this later.</p>
        <label className="switch-row">
          <span>
            <strong>WhatsApp</strong>
            <small>The weekly summary and urgent alerts</small>
          </span>
          <input type="checkbox" name="whatsapp" defaultChecked={choices.whatsapp} />
        </label>
        <label className="switch-row">
          <span>
            <strong>Email</strong>
            <small>The weekly summary, if WhatsApp isn’t for you</small>
          </span>
          <input type="checkbox" name="email" defaultChecked={choices.email} />
        </label>
        <label className="switch-row">
          <span>
            <strong>Notifications in this browser</strong>
            <small>Alerts while you have Chom open on this device</small>
          </span>
          <input type="checkbox" name="push" defaultChecked={choices.push} />
        </label>
      </fieldset>

      <label className="consent-agree">
        <input type="checkbox" name="agree" required defaultChecked={choices.agree} />
        <span>{agreement}</span>
      </label>

      {error && (
        <p className="form-error" role="alert">
          {error}
        </p>
      )}

      <div className="consent-actions">
        <button className="button" type="submit" disabled={pending}>
          {pending ? 'Saving…' : 'I agree, continue'}
        </button>
      </div>
    </form>
  );
}
