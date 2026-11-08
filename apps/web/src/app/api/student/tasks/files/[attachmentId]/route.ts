import { NextResponse } from 'next/server';

import { UUID, noStore } from '@/lib/student-tasks';
import { createClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

/**
 * Downloads a file attached to a task: a short-lived signed link to the private
 * bucket. Only someone who can see the task finds the attachment (row-level security)
 * or can sign its file (storage policies).
 */
export async function GET(
  _request: Request,
  { params }: { params: Promise<{ attachmentId: string }> },
) {
  const { attachmentId } = await params;
  if (!UUID.test(attachmentId)) {
    return NextResponse.json({ error: 'not_found' }, { status: 404, headers: noStore });
  }

  const supabase = await createClient();
  const { data: attachment } = await supabase
    .from('task_attachments')
    .select('storage_path, file_name')
    .eq('id', attachmentId)
    .maybeSingle();
  if (!attachment) {
    return NextResponse.json({ error: 'not_found' }, { status: 404, headers: noStore });
  }

  const { data: signed } = await supabase.storage
    .from('task-files')
    .createSignedUrl(attachment.storage_path, 60, { download: attachment.file_name });
  if (!signed?.signedUrl) {
    return NextResponse.json({ error: 'not_found' }, { status: 404, headers: noStore });
  }
  return NextResponse.redirect(signed.signedUrl, { status: 303, headers: noStore });
}
