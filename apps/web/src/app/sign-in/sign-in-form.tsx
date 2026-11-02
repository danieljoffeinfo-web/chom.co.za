'use client';

import { type FormEvent, useState } from 'react';

import { createClient } from '@/lib/supabase/browser';

import styles from './sign-in.module.css';

type State = { status: 'idle' | 'sending' | 'sent' } | { status: 'error'; message: string };

export function SignInForm() {
  const [email, setEmail] = useState('');
  const [state, setState] = useState<State>({ status: 'idle' });

  async function onSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setState({ status: 'sending' });
    const supabase = createClient();
    const { error } = await supabase.auth.signInWithOtp({
      email: email.trim(),
      options: { emailRedirectTo: `${window.location.origin}/auth/callback` },
    });
    setState(error ? { status: 'error', message: error.message } : { status: 'sent' });
  }

  if (state.status === 'sent') {
    return (
      <div className={styles.sent} role="status">
        <p className={styles.sentTitle}>Check your inbox</p>
        <p className={styles.muted}>
          We sent a sign-in link to <strong>{email.trim()}</strong>. Open it on this device to
          continue.
        </p>
        <button
          className={styles.linkButton}
          type="button"
          onClick={() => setState({ status: 'idle' })}
        >
          Use a different email
        </button>
      </div>
    );
  }

  return (
    <form className={styles.form} onSubmit={onSubmit}>
      <label className={styles.label} htmlFor="email">
        Email
      </label>
      <input
        id="email"
        className={styles.input}
        type="email"
        autoComplete="email"
        inputMode="email"
        required
        placeholder="you@school.co.za"
        value={email}
        onChange={(event) => setEmail(event.target.value)}
      />
      {state.status === 'error' && (
        <p className={styles.error} role="alert">
          {state.message}
        </p>
      )}
      <button className={styles.primary} type="submit" disabled={state.status === 'sending'}>
        {state.status === 'sending' ? 'Sending…' : 'Email me a sign-in link'}
      </button>
      <p className={styles.hint}>“Sign in with Microsoft” for schools is coming soon.</p>
    </form>
  );
}
