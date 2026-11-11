'use client';

import { PASSWORD_RULE, passwordProblem } from '@chom/api';
import { type AuthError, isAuthWeakPasswordError } from '@supabase/supabase-js';
import { useRouter } from 'next/navigation';
import { type FormEvent, useState } from 'react';

import { type LoginAs, loginAsParam } from '@/lib/login-intent';
import { createClient } from '@/lib/supabase/browser';

import styles from './sign-in.module.css';

/**
 * Signing in:
 *   - Usually: email and password.
 *   - The first time (or after forgetting the password): email and a new password,
 *     then the code we email them. The code proves the email is theirs; only then is
 *     the password saved. Their full name comes next, on /start.
 */
type Step =
  | 'sign-in' // email + password
  | 'set-up' // email + a new password, then we email a code
  | 'code' // the emailed code
  | 'new-password'; // signed in, but Supabase refused the password: choose another

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

function passwordRefused(error: AuthError): string {
  if (isAuthWeakPasswordError(error) && error.reasons.includes('pwned')) {
    return 'That password has appeared in a data leak elsewhere, so it isn’t safe. Please choose a different one.';
  }
  return `Choose a stronger password: ${PASSWORD_RULE.toLowerCase()}`;
}

export function SignInForm({ loginAs }: { loginAs: LoginAs }) {
  const router = useRouter();
  const [step, setStep] = useState<Step>('sign-in');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [code, setCode] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  function goTo(next: Step) {
    setStep(next);
    setError(null);
    setNotice(null);
    if (next !== 'code') setCode('');
    if (next === 'set-up' || next === 'new-password') setPassword('');
  }

  function finish() {
    router.push(`/start${loginAsParam(loginAs)}`);
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

  async function savePassword(): Promise<boolean> {
    const { error: saveError } = await createClient().auth.updateUser({ password });
    // Choosing the password they already have is fine: they know it.
    if (saveError && saveError.code !== 'same_password') {
      console.error('Saving the password failed', saveError.status, saveError.code);
      setError(saveError.code === 'weak_password' ? passwordRefused(saveError) : TRY_AGAIN);
      return false;
    }
    return true;
  }

  function onSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    void run(async () => {
      const supabase = createClient();
      if (step === 'sign-in') {
        const { error: signInError } = await supabase.auth.signInWithPassword({
          email: email.trim(),
          password,
        });
        if (signInError) {
          console.error('Sign-in failed', signInError.status, signInError.code);
          setError(
            rateLimited(signInError) ??
              (signInError.code === 'invalid_credentials'
                ? 'That email or password is wrong.'
                : TRY_AGAIN),
          );
          return;
        }
        finish();
      } else if (step === 'set-up') {
        const problem = passwordProblem(password);
        if (problem) {
          setError(problem);
          return;
        }
        if (await sendCode()) goTo('code');
      } else if (step === 'code') {
        const { error: codeError } = await supabase.auth.verifyOtp({
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
        if (await savePassword()) {
          finish();
        } else {
          // They're signed in now; only the password needs another go.
          setStep('new-password');
          setPassword('');
        }
      } else {
        const problem = passwordProblem(password);
        if (problem) {
          setError(problem);
          return;
        }
        if (await savePassword()) finish();
      }
    });
  }

  const choosing = step === 'set-up' || step === 'new-password';

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
          {step === 'new-password' ? (
            <p className={styles.muted}>
              Your email is confirmed. That password can’t be used, so please choose another.
            </p>
          ) : (
            <>
              {step === 'set-up' && (
                <p className={styles.muted}>
                  Choose a new password, and we’ll email you a code to confirm it’s you.
                </p>
              )}
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
            </>
          )}
          <label className={styles.label} htmlFor="password">
            {choosing ? 'Choose a password' : 'Password'}
          </label>
          <input
            id="password"
            className={styles.input}
            type="password"
            autoComplete={choosing ? 'new-password' : 'current-password'}
            required
            minLength={choosing ? 8 : undefined}
            value={password}
            onChange={(event) => setPassword(event.target.value)}
          />
          {choosing && <p className={styles.fieldHint}>{PASSWORD_RULE}</p>}
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
        {busy
          ? 'One moment…'
          : step === 'sign-in'
            ? 'Sign in'
            : step === 'set-up'
              ? 'Email me a code'
              : step === 'code'
                ? 'Continue'
                : 'Save password'}
      </button>

      {step === 'sign-in' && (
        <button className={styles.linkButton} type="button" onClick={() => goTo('set-up')}>
          Forgot your password?
        </button>
      )}
      {step === 'set-up' && (
        <button className={styles.linkButton} type="button" onClick={() => goTo('sign-in')}>
          I have a password: sign in
        </button>
      )}
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
          <button className={styles.linkButton} type="button" onClick={() => goTo('set-up')}>
            Use a different email
          </button>
        </div>
      )}
    </form>
  );
}
