'use client';

import { type Database, authCookieOptions } from '@chom/api';
import { createBrowserClient } from '@supabase/ssr';

import { supabaseEnv } from './env';

/** A Supabase client for Client Components, acting as the signed-in user. */
export function createClient() {
  const { url, publishableKey } = supabaseEnv();
  return createBrowserClient<Database>(url, publishableKey, {
    // Shared with chom.co.za / staff.chom.co.za, so one sign-in covers both.
    cookieOptions: authCookieOptions(window.location.host),
  });
}
