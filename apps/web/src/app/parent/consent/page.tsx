import { redirect } from 'next/navigation';

import { Message } from '@/components/message';
import { currentLinks } from '@/lib/parent/current-parent';
import { CONSENT_TEXTS } from '@/lib/parent/consent';
import { gradeLabel } from '@/lib/parent/parent';
import { createClient } from '@/lib/supabase/server';

import { ConsentForm } from './consent-form';

export const metadata = { title: 'Before you start · Chom Learn' };

/**
 * POPIA consent (spec §3), shown at first sign-in and whenever the consent text
 * changes. Until a parent agrees, the database shows them nothing about their child.
 */
export default async function ConsentPage() {
  const supabase = await createClient();
  const [links, { data: current, error }, { data: saved, error: savedError }] = await Promise.all([
    currentLinks(),
    supabase
      .from('parent_consent_versions')
      .select('version')
      .lte('published_at', new Date().toISOString())
      .order('published_at', { ascending: false })
      .order('version', { ascending: false })
      .limit(1)
      .maybeSingle(),
    // Their channels from an earlier consent, so agreeing again doesn't reset them.
    supabase.from('parent_notification_channels').select('whatsapp, email, push').maybeSingle(),
  ]);
  if (error) throw error;
  if (savedError) throw savedError;

  // Withdrawn links can consent again from here; blocked ones never reach the app.
  const pending = links.filter(
    (l) => !l.consented && l.status !== 'learner_revoked' && l.status !== 'blocked',
  );
  if (!pending.length) redirect('/parent');

  const text = current ? CONSENT_TEXTS[current.version] : undefined;
  if (!text) {
    return (
      <Message title="We’re updating our terms" signOut>
        Please come back in a little while. Your child’s information is safe in the meantime.
      </Message>
    );
  }

  return (
    <main className="consent-page" id="main">
      <div className="consent-card">
        <p className="cd-label">chom learn · for parents</p>
        <h1>Before you start</h1>
        <p className="consent-lede">{text.intro}</p>

        <ul className="consent-children" aria-label="Your children on Chom">
          {pending.map((l) => (
            <li key={l.guardianshipId}>
              <strong>{l.childName}</strong>
              <small>{[gradeLabel(l.grade), l.schoolName].filter(Boolean).join(' · ')}</small>
              {l.status === 'consent_withdrawn' && (
                <small>You withdrew consent for {l.childName}. Agreeing turns it back on.</small>
              )}
            </li>
          ))}
        </ul>

        <section>
          <h2>{text.processing.title}</h2>
          <ul className="consent-points">
            {text.processing.points.map((p) => (
              <li key={p}>{p}</li>
            ))}
          </ul>
        </section>

        <div className="consent-columns">
          <section>
            <h2>You’ll see</h2>
            <ul className="consent-points yes">
              {text.canSee.map((p) => (
                <li key={p}>{p}</li>
              ))}
            </ul>
          </section>
          <section>
            <h2>You won’t see</h2>
            <ul className="consent-points no">
              {text.cannotSee.map((p) => (
                <li key={p}>{p}</li>
              ))}
            </ul>
            <p className="consent-why">
              Teenagers use a tutor honestly when they know their questions are private.
            </p>
          </section>
        </div>

        <p className="consent-rights">{text.rights}</p>

        <ConsentForm version={text.version} agreement={text.agreement} saved={saved} />

        <form action="/sign-out" method="post" className="consent-signout">
          <button className="text-button" type="submit">
            Not now, sign out
          </button>
        </form>
        <p className="consent-version">Consent version {text.version}</p>
      </div>
    </main>
  );
}
