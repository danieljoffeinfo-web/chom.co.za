'use client';

import type { AuthError } from '@supabase/supabase-js';
import { useRouter } from 'next/navigation';
import { type FormEvent, useState } from 'react';

import { type LoginAs, loginAsParam } from '@/lib/login-intent';
import { createClient } from '@/lib/supabase/browser';

import styles from './sign-in.module.css';

/**
 * Signing in, with no password: their email, then the 6-digit code we email them. The
 * code proves the email is theirs. Their full name comes next, on /start.
 */
type Step =
  | 'email' // their email; we send a code
  | 'code'; // the emailed code

const TRY_AGAIN = 'Something went wrong. Please try again in a moment.';

function rateLimited(error: AuthError): string | null {
  if (error.code === 'over_email_send_rate_limit') {
    return 'We’ve sent you a code very recently. Please wait a minute, then ask again, and use only the newest email.';
  }
  if (error.status === 429 || error.code === 'over_request_rate_limit') {
    return 'Too many attempts. Please wait a few minutes, then try again.';
  }
  return null;
}

export function SignInForm({ loginAs }: { loginAs: LoginAs }) {
  const router = useRouter();
  const [step, setStep] = useState<Step>('email');
  const [email, setEmail] = useState('');
  const [code, setCode] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  function goTo(next: Step) {
    setStep(next);
    setError(null);
    setNotice(null);
    setCode('');
  }

  // Runs one step, never leaving the button stuck (for example, no connection).
  async function run(action: () => Promise<void>) {
    setBusy(true);
    setError(null);
    setNotice(null);
    try {
      await action();
    } catch (thrown) {
      console.error('Sign-in failed', thrown);
      setError(TRY_AGAIN);
    } finally {
      setBusy(false);
    }
  }

  async function sendCode(): Promise<boolean> {
    const { error: sendError } = await createClient().auth.signInWithOtp({
      email: email.trim(),
    });
    if (sendError) {
      console.error('Sending the code failed', sendError.status, sendError.code);
      setError(
        rateLimited(sendError) ??
          (sendError.code === 'email_address_invalid'
            ? 'We can’t send email to that address. Please use the email your school knows you by.'
            : TRY_AGAIN),
      );
      return false;
    }
    return true;
  }

  function onSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    void run(async () => {
      if (step === 'email') {
        if (await sendCode()) goTo('code');
        return;
      }
      const { error: codeError } = await createClient().auth.verifyOtp({
        email: email.trim(),
        token: code.trim(),
        type: 'email',
      });
      if (codeError) {
        console.error('Checking the code failed', codeError.status, codeError.code);
        setError(
          rateLimited(codeError) ??
            'That code is wrong or has expired. Check the newest email from us, or send a new code.',
        );
        return;
      }
      router.push(`/start${loginAsParam(loginAs)}`);
    });
  }

  return (
    <form className={styles.form} onSubmit={onSubmit}>
      {step === 'code' ? (
        <>
          <p className={styles.sentTitle}>Check your email</p>
          <p className={styles.muted}>
            We sent a code to <strong>{email.trim()}</strong>. Type it in below.
          </p>
          <label className={styles.label} htmlFor="code">
            Code
          </label>
          <input
            id="code"
            className={`${styles.input} ${styles.code}`}
            type="text"
            inputMode="numeric"
            autoComplete="one-time-code"
            pattern="[0-9]{6,10}"
            maxLength={10}
            required
            autoFocus
            value={code}
            onChange={(event) => setCode(event.target.value.replace(/\D/g, ''))}
          />
        </>
      ) : (
        <>
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
          <p className={styles.fieldHint}>We’ll email you a code. No password needed.</p>
        </>
      )}

      {error && (
        <p className={styles.error} role="alert">
          {error}
        </p>
      )}
      {notice && (
        <p className={styles.notice} role="status">
          {notice}
        </p>
      )}

      <button className={styles.primary} type="submit" disabled={busy}>
        {busy ? 'One moment…' : step === 'email' ? 'Email me a code' : 'Continue'}
      </button>

      {step === 'code' && (
        <div className={styles.links}>
          <button
            className={styles.linkButton}
            type="button"
            disabled={busy}
            onClick={() =>
              void run(async () => {
                if (await sendCode()) setNotice('We sent a new code. Use the newest email.');
              })
            }
          >
            Send a new code
          </button>
          <button className={styles.linkButton} type="button" onClick={() => goTo('email')}>
            Use a different email
          </button>
        </div>
      )}
    </form>
  );
}
