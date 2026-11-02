import { createServerClient } from '@supabase/ssr';
import { type NextRequest, NextResponse } from 'next/server';

import { supabaseEnv } from '@/lib/supabase/env';

/**
 * Runs before every page: refreshes the signed-in user's session so its cookies stay
 * valid, and keeps signed-out visitors out of the app's pages.
 */
export async function proxy(request: NextRequest) {
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
  // The HTML prototypes use sample data only, so they stay viewable signed out
  // (for showing schools).
  const isPrototype = ['/app', '/teacher', '/shared'].some(
    (p) => path === p || path.startsWith(`${p}/`),
  );
  const isPublic =
    path === '/' ||
    path.startsWith('/sign-in') ||
    path === '/sign-out' ||
    path.startsWith('/auth/') ||
    isPrototype;
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
