'use server';

import { headers } from 'next/headers';
import { redirect } from 'next/navigation';

import { createClient } from '@/lib/supabase/server';

// A plain IPv4 or IPv6 address, so a strange header can't break the insert.
const IP = /^(?:\d{1,3}(?:\.\d{1,3}){3}|[0-9a-fA-F:]{2,39})$/;

export type ConsentState = { error: string | null };

/**
 * Records the parent's consent to the version they read, with the channels they chose.
 * The IP and browser come from the request, as POPIA evidence of where consent was
 * given. The database checks the version is current and covers each of their children.
 */
export async function recordConsent(_: ConsentState, form: FormData): Promise<ConsentState> {
  if (form.get('agree') !== 'on') {
    return { error: 'Please tick the box to say you agree, or sign out if you don’t.' };
  }

  const request = await headers();
  const forwarded = request.get('x-forwarded-for')?.split(',')[0]?.trim() ?? '';
  const ip = IP.test(forwarded) ? forwarded : null;

  const supabase = await createClient();
  const { error } = await supabase.rpc('record_parent_consent', {
    p_version: String(form.get('version') ?? ''),
    p_whatsapp: form.get('whatsapp') === 'on',
    p_email: form.get('email') === 'on',
    p_push: form.get('push') === 'on',
    p_ip: ip ?? undefined,
    p_user_agent: request.get('user-agent')?.slice(0, 1000) ?? undefined,
  });
  if (error) {
    // The version changed while they were reading: show the new one.
    if (error.code === '22023') redirect('/parent/consent');
    return { error: 'We couldn’t save your consent. Please try again in a moment.' };
  }

  redirect('/parent');
}
