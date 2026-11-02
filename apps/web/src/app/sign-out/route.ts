import { type NextRequest, NextResponse } from 'next/server';

import { createClient } from '@/lib/supabase/server';

async function signOut(request: NextRequest) {
  const supabase = await createClient();
  await supabase.auth.signOut();
  return NextResponse.redirect(`${request.nextUrl.origin}/`, { status: 303 });
}

// POST from the app's own buttons; GET for the prototype dashboard's "Sign out" link.
export const POST = signOut;
export const GET = signOut;
