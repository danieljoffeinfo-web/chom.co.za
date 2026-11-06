import Link from 'next/link';

import { currentLinks, currentParent } from '@/lib/parent/current-parent';
import { RELATIONSHIP_LABELS, gradeLabel, type LinkStatus } from '@/lib/parent/parent';
import { createClient } from '@/lib/supabase/server';

import { ChannelsForm, WithdrawButton } from './account-forms';

export const metadata = { title: 'Account · Chom Parent' };

const STATUS_LABELS: Record<LinkStatus, string> = {
  invited: 'Waiting for your consent',
  active: 'Linked',
  blocked: 'Linked',
  consent_withdrawn: 'Consent withdrawn',
  learner_revoked: 'Kept private by your child',
};

const DATE = new Intl.DateTimeFormat('en-ZA', {
  day: 'numeric',
  month: 'long',
  year: 'numeric',
  timeZone: 'Africa/Johannesburg',
});

/** Account (spec §5.9): linked children, consent, how Chom reaches you. */
export default async function Account() {
  const supabase = await createClient();
  const [parent, links, { data: consents }, { data: channels }] = await Promise.all([
    currentParent(),
    currentLinks(),
    supabase
      .from('parent_consents')
      .select('guardianship_id, consent_version, granted_at, withdrawn_at')
      .order('granted_at', { ascending: false }),
    supabase.from('parent_notification_channels').select('whatsapp, email, push').maybeSingle(),
  ]);
  if (!parent) return null;

  const latestConsent = (guardianshipId: string) =>
    consents?.find((c) => c.guardianship_id === guardianshipId);

  return (
    <>
      <header className="view-header">
        <div>
          <h1>Account</h1>
          <p>Signed in as {parent.fullName}.</p>
        </div>
      </header>

      <div className="account-grid">
        <section className="content-card">
          <h2>Your children</h2>
          <ul className="linked-children">
            {links.map((l) => {
              const consent = latestConsent(l.guardianshipId);
              return (
                <li key={l.guardianshipId}>
                  <div>
                    <strong>{l.childName}</strong>
                    <small>
                      {[gradeLabel(l.grade), l.schoolName, RELATIONSHIP_LABELS[l.relationship]]
                        .filter(Boolean)
                        .join(' · ')}
                      {l.isPrimary ? ' · Primary contact' : ''}
                    </small>
                    <small>
                      {STATUS_LABELS[l.status]}
                      {consent && !consent.withdrawn_at && l.consented
                        ? ` · consent given ${DATE.format(new Date(consent.granted_at))} (version ${consent.consent_version})`
                        : ''}
                    </small>
                  </div>
                  {l.status === 'active' && l.consented && (
                    <WithdrawButton guardianshipId={l.guardianshipId} childName={l.childName} />
                  )}
                  {l.status === 'consent_withdrawn' && (
                    <Link className="text-button" href="/parent/consent">
                      Give consent again
                    </Link>
                  )}
                </li>
              );
            })}
          </ul>
          <p className="form-note">
            Missing a child? Ask their school to add you as a parent with this email address.
          </p>
        </section>

        <section className="content-card">
          <h2>How Chom reaches you</h2>
          <ChannelsForm
            initial={{
              whatsapp: channels?.whatsapp ?? false,
              email: channels?.email ?? true,
              push: channels?.push ?? false,
            }}
          />
        </section>

        <section className="content-card">
          <h2>Language</h2>
          <p>English. Afrikaans and isiZulu are coming.</p>
        </section>

        <section className="content-card">
          <h2>Sign out</h2>
          <p>Sign out of Chom on this device.</p>
          <form action="/sign-out" method="post">
            <button className="button secondary" type="submit">
              Sign out
            </button>
          </form>
        </section>
      </div>
    </>
  );
}
