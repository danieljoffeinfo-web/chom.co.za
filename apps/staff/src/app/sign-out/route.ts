import { type NextRequest, NextResponse } from 'next/server';

import { staffSignInUrl } from '@/lib/canonical-host';
import { createClient } from '@/lib/supabase/server';

/** Signs out, then back to the sign-in page (chom.co.za in production). */
export async function POST(request: NextRequest) {
  const supabase = await createClient();
  await supabase.auth.signOut();
  // Signing out here also signs out of chom.co.za (the sign-in is shared).
  return NextResponse.redirect(new URL(staffSignInUrl(process.env.VERCEL_ENV), request.nextUrl), {
    status: 303,
  });
}
