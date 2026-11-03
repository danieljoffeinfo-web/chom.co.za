import { authCookieOptions } from '@chom/api';
import { createServerClient } from '@supabase/ssr';
import { type NextRequest, NextResponse } from 'next/server';

import { canonicalRedirect, staffSignInUrl } from '@/lib/canonical-host';
import { supabaseEnv } from '@/lib/supabase/env';

/**
 * Runs before every page: sends production visitors on any other address to
 * staff.chom.co.za, refreshes the signed-in user's session so its cookies stay valid,
 * and sends signed-out visitors to the sign-in page.
 */
export async function proxy(request: NextRequest) {
  const canonical = canonicalRedirect(
    request.headers.get('host'),
    request.nextUrl.pathname + request.nextUrl.search,
    process.env.VERCEL_ENV,
  );
  if (canonical) return NextResponse.redirect(canonical, 308);

  // Everyone signs in at chom.co.za; this site shares that sign-in.
  const signInUrl = staffSignInUrl(process.env.VERCEL_ENV);
  const path = request.nextUrl.pathname;
  if (signInUrl.startsWith('https://') && path.startsWith('/sign-in')) {
    // Keep "that link expired" (error=link) for the chom.co.za sign-in page.
    const target = new URL(signInUrl);
    const error = request.nextUrl.searchParams.get('error');
    if (error) target.searchParams.set('error', error);
    return NextResponse.redirect(target);
  }

  const { url, publishableKey } = supabaseEnv();
  let response = NextResponse.next({ request });

  const supabase = createServerClient(url, publishableKey, {
    cookieOptions: authCookieOptions(request.headers.get('host')),
    cookies: {
      getAll() {
        return request.cookies.getAll();
      },
      setAll(cookiesToSet, headers) {
        for (const { name, value } of cookiesToSet) request.cookies.set(name, value);
        response = NextResponse.next({ request });
        for (const { name, value, options } of cookiesToSet) {
          response.cookies.set(name, value, options);
        }
        for (const [key, value] of Object.entries(headers)) response.headers.set(key, value);
      },
    },
  });

  // Validates the session with Supabase Auth (and refreshes it if needed).
  const { data } = await supabase.auth.getClaims();
  const signedIn = Boolean(data?.claims);

  const isPublic = path.startsWith('/sign-in') || path === '/sign-out' || path.startsWith('/auth/');
  if (!signedIn && !isPublic) {
    return NextResponse.redirect(new URL(signInUrl, request.nextUrl));
  }

  return response;
}

export const config = {
  // Everything except static files and images.
  matcher: [
    '/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp|ico)$).*)',
  ],
};
