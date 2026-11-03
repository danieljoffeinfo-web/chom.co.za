import { type Database, authCookieOptions } from '@chom/api';
import { createServerClient } from '@supabase/ssr';
import { cookies, headers } from 'next/headers';

import { supabaseEnv } from './env';

/**
 * A Supabase client for Server Components, Route Handlers and Server Actions, acting
 * as the signed-in user (their session is in cookies). Create one per request.
 */
export async function createClient() {
  // Read cookies first: it marks the page as per-request, so builds never try to
  // pre-render signed-in pages (or need the Supabase settings at build time).
  const cookieStore = await cookies();
  const host = (await headers()).get('host');
  const { url, publishableKey } = supabaseEnv();

  return createServerClient<Database>(url, publishableKey, {
    // Shared with chom.co.za / staff.chom.co.za, so one sign-in covers both.
    cookieOptions: authCookieOptions(host),
    cookies: {
      getAll() {
        return cookieStore.getAll();
      },
      setAll(cookiesToSet) {
        try {
          for (const { name, value, options } of cookiesToSet) {
            cookieStore.set(name, value, options);
          }
        } catch {
          // Server Components can't set cookies. The proxy refreshes the session
          // on every request, so this is safe to ignore here.
        }
      },
    },
  });
}
