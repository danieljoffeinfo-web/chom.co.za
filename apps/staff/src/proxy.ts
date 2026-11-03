import { createServerClient } from '@supabase/ssr';
import { type NextRequest, NextResponse } from 'next/server';

import { canonicalRedirect } from '@/lib/canonical-host';
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

  const { url, publishableKey } = supabaseEnv();
  let response = NextResponse.next({ request });

  const supabase = createServerClient(url, publishableKey, {
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

  const path = request.nextUrl.pathname;
  const isPublic = path.startsWith('/sign-in') || path === '/sign-out' || path.startsWith('/auth/');
  if (!signedIn && !isPublic) {
    const signIn = request.nextUrl.clone();
    signIn.pathname = '/sign-in';
    signIn.search = '';
    return NextResponse.redirect(signIn);
  }

  return response;
}

export const config = {
  // Everything except static files and images.
  matcher: [
    '/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp|ico)$).*)',
  ],
};
