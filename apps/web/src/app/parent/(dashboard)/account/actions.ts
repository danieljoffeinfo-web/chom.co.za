'use server';

import { revalidatePath } from 'next/cache';

import { currentParent } from '@/lib/parent/current-parent';
import { createClient } from '@/lib/supabase/server';

/** Withdraws consent for one child. Their information is hidden at once. */
export async function withdrawConsent(guardianshipId: string): Promise<{ error: string | null }> {
  const supabase = await createClient();
  const { error } = await supabase.rpc('withdraw_parent_consent', {
    p_guardianship_id: guardianshipId,
  });
  if (error) return { error: 'We couldn’t withdraw your consent. Please try again.' };
  revalidatePath('/parent', 'layout');
  return { error: null };
}

export type ChannelsState = { saved: boolean; error: string | null };

/** Saves which channels Chom may use to reach this parent. */
export async function saveChannels(_: ChannelsState, form: FormData): Promise<ChannelsState> {
  const parent = await currentParent();
  if (!parent) return { saved: false, error: 'Please sign in again.' };

  const supabase = await createClient();
  const { error } = await supabase.from('parent_notification_channels').upsert({
    profile_id: parent.profileId,
    whatsapp: form.get('whatsapp') === 'on',
    email: form.get('email') === 'on',
    push: form.get('push') === 'on',
  });
  if (error) return { saved: false, error: 'We couldn’t save that. Please try again.' };
  return { saved: true, error: null };
}
