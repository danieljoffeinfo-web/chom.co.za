import { createChomClient, readPublicSupabaseEnv } from '@chom/api';

/** React Native Supabase client. Call after Expo has loaded env. */
export function createMobileSupabase() {
  const { supabaseUrl, supabaseAnonKey } = readPublicSupabaseEnv();
  return createChomClient(supabaseUrl, supabaseAnonKey, {
    auth: {
      detectSessionInUrl: false,
      persistSession: true,
      autoRefreshToken: true,
    },
  });
}
