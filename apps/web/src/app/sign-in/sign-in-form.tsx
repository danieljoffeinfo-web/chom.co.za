'use client';

import type { AuthError } from '@supabase/supabase-js';
import { type FormEvent, useState } from 'react';

import { LOGIN_AS_COOKIE, type LoginAs } from '@/lib/login-intent';
import { createClient } from '@/lib/supabase/browser';

import styles from './sign-in.module.css';

type State = { status: 'idle' | 'sending' | 'sent' } | { status: 'error'; message: string };

const GENERIC_ERROR = 'We couldn’t send your sign-in link. Please try again in a moment.';

/**
 * Plain words for the errors people can actually hit when asking for a link. Supabase
 * error codes: https://supabase.com/docs/guides/auth/debugging/error-codes
 */
function signInErrorMessage(error: AuthError): string {
  if (error.code === 'over_email_send_rate_limit') {
    return 'Too many sign-in emails have been asked for. Please wait a few minutes before asking for a new one, and use only the newest email we send you.';
  }
  if (error.status === 429 || error.code === 'over_request_rate_limit') {
    return 'Too many attempts. Please wait a few minutes, then try again.';
  }
  if (error.code === 'email_address_invalid') {
    return 'We can’t send sign-in emails to that address. Please use your school email.';
  }
  return GENERIC_ERROR;
}

export function SignInForm({ loginAs }: { loginAs: LoginAs }) {
  const [email, setEmail] = useState('');
  const [state, setState] = useState<State>({ status: 'idle' });

  async function onSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setState({ status: 'sending' });
    // Remember which door was used until the email link is clicked (one hour).
    document.cookie =
      loginAs === 'staff'
        ? `${LOGIN_AS_COOKIE}=staff; path=/; max-age=3600; samesite=lax`
        : `${LOGIN_AS_COOKIE}=; path=/; max-age=0; samesite=lax`;
    let error: AuthError | null;
    try {
      const supabase = createClient();
      ({ error } = await supabase.auth.signInWithOtp({
        email: email.trim(),
        options: { emailRedirectTo: `${window.location.origin}/auth/callback` },
      }));
    } catch (thrown) {
      // Never leave the button stuck on "Sending…" (for example, no connection).
      console.error('Sign-in link failed', thrown);
      setState({ status: 'error', message: GENERIC_ERROR });
      return;
    }
    if (error) {
      console.error('Sign-in link failed', error.status, error.code, error.message);
      setState({ status: 'error', message: signInErrorMessage(error) });
      return;
    }
    setState({ status: 'sent' });
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
