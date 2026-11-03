/** Where everyone signs in: students, parents and staff. */
export const SIGN_IN_ORIGIN = 'https://chom.co.za';

/** Where the staff dashboard lives. It shares the sign-in with chom.co.za. */
export const STAFF_ORIGIN = 'https://staff.chom.co.za';

/**
 * The sign-in cookie's name. Both apps must use the same one. It replaced Supabase's
 * default name when the cookie started being shared, so old per-site cookies are
 * simply ignored (people sign in once more).
 */
export const AUTH_COOKIE_NAME = 'chom-auth';

const SHARED_DOMAIN = 'chom.co.za';

/**
 * Cookie settings for the Supabase sign-in, for a request to `host`. On chom.co.za
 * and its subdomains (staff.chom.co.za) the cookie is set for the whole domain, so
 * signing in once at chom.co.za also signs you in to the staff dashboard. Anywhere
 * else (previews, localhost) it stays on that one address.
 */
export function authCookieOptions(host: string | null | undefined): {
  name: string;
  domain?: string;
} {
  const hostname = (host ?? '').split(':')[0]?.toLowerCase() ?? '';
  const shared = hostname === SHARED_DOMAIN || hostname.endsWith(`.${SHARED_DOMAIN}`);
  return shared ? { name: AUTH_COOKIE_NAME, domain: SHARED_DOMAIN } : { name: AUTH_COOKIE_NAME };
}
