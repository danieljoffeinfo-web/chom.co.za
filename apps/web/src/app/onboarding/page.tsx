import { redirect } from 'next/navigation';

import { loadStudentContext } from '@/lib/student';
import { createClient } from '@/lib/supabase/server';

import { Onboarding } from './onboarding';

export const metadata = { title: 'Welcome · Chom Learn' };

export default async function OnboardingPage() {
  const supabase = await createClient();
  const student = await loadStudentContext(supabase);
  if (!student) redirect('/start');
  return <Onboarding student={student} />;
}
