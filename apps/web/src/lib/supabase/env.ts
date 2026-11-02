import { isServerOnlyKey } from '@chom/api';

/**
 * The Supabase project the web app talks to. Both values are public: every table is
 * protected by row-level security. Set them in Vercel (and .env.local for local dev):
 *   NEXT_PUBLIC_SUPABASE_URL, NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY
 */
export function supabaseEnv(): { url: string; publishableKey: string } {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const publishableKey = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
  if (!url || !publishableKey) {
    throw new Error(
      'Missing NEXT_PUBLIC_SUPABASE_URL or NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY. See apps/web/.env.example.',
    );
  }
  if (isServerOnlyKey(publishableKey)) {
    throw new Error(
      'NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY is a secret key; use the publishable key.',
    );
  }
  return { url, publishableKey };
}
