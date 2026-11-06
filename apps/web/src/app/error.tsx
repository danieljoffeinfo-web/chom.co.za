'use client';

import { Message } from '@/components/message';
import styles from '@/components/message.module.css';

/**
 * Catches a failed load of home, onboarding or the sign-in handoff. Retry asks the
 * server again; resetting the screen alone would redraw the same failure.
 */
export default function AppError({ retry }: { error: Error; retry: () => void }) {
  return (
    <Message
      title="We couldn’t load Chom"
      signOut
      action={
        <button className={styles.primary} type="button" onClick={retry}>
          Try again
        </button>
      }
    >
      <p>Something went wrong on our side. Please try again in a moment.</p>
    </Message>
  );
}
