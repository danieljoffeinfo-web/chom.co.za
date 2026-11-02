import { createChomClient, readPublicSupabaseEnv } from '@chom/api';

/** Browser / client-component Supabase client for the web app. */
export function createBrowserSupabase() {
  const { supabaseUrl, supabaseAnonKey } = readPublicSupabaseEnv();
  return createChomClient(supabaseUrl, supabaseAnonKey);
}
