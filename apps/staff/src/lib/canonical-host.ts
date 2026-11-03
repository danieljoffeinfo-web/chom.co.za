/** The one address the staff dashboard is served from in production. */
export const STAFF_HOST = 'staff.chom.co.za';

/**
 * Where to send a production request that arrived on any other address (for example
 * a *.vercel.app link), or null if it's already on the right one.
 *
 * Sign-in links must start and end on the same address: Supabase only returns to
 * approved addresses (otherwise it falls back to chom.co.za, the student site), and
 * the sign-in code is tied to a cookie on the address that asked for it.
 */
export function canonicalRedirect(
  host: string | null,
  pathAndQuery: string,
  vercelEnv: string | undefined,
): string | null {
  if (vercelEnv !== 'production') return null; // Previews and local dev stay put.
  if (!host || host.toLowerCase() === STAFF_HOST) return null;
  return `https://${STAFF_HOST}${pathAndQuery}`;
}
