import type { createClient } from '@/lib/supabase/server';

type Client = Awaited<ReturnType<typeof createClient>>;

/**
 * Whether the signed-in person has confirmed their name (the last step of their first
 * sign-in), and the email they're signed in with. Null if they have no profile, or if
 * it couldn't be read: the name step is skipped rather than blocking sign-in. The name
 * itself is never sent to the page: the person has to know it.
 */
export async function loadMyName(
  supabase: Client,
): Promise<{ email: string; confirmed: boolean } | null> {
  const { data: claims } = await supabase.auth.getClaims();
  const userId = claims?.claims.sub;
  if (!userId) return null;
  const { data } = await supabase
    .from('profiles')
    .select('name_confirmed_at')
    .eq('user_id', userId)
    .maybeSingle();
  if (!data) return null;
  const email = typeof claims.claims.email === 'string' ? claims.claims.email : '';
  return { email, confirmed: data.name_confirmed_at !== null };
}
