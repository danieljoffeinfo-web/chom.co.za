import { Icon } from '@chom/dashboard';
import Link from 'next/link';
import { redirect } from 'next/navigation';

import { currentLinks, currentParent } from '@/lib/parent/current-parent';

export const metadata = { title: 'Home · Chom Parent' };

/** /parent: straight to the first child's Home, or explain why there's no one to show. */
export default async function ParentIndex() {
  const [parent, links] = await Promise.all([currentParent(), currentLinks()]);
  const first = parent?.children[0];
  if (first) redirect(`/parent/${first.id}`);

  const withdrawn = links.filter((l) => l.status === 'consent_withdrawn');
  const revoked = links.filter((l) => l.status === 'learner_revoked');

  return (
    <section className="panel">
      <div className="empty-message">
        <Icon name="heart" />
        <h2>There’s nothing to show yet</h2>
        {withdrawn.length > 0 && (
          <p>
            You withdrew consent for {withdrawn.map((l) => l.childName).join(' and ')}, so their
            information is hidden. You can give consent again at any time.
          </p>
        )}
        {revoked.length > 0 && (
          <p>
            {revoked.map((l) => l.childName).join(' and ')} chose to keep their schoolwork private
            now that they’re 18. You’ll still get school news and events.
          </p>
        )}
        {withdrawn.length > 0 && (
          <Link className="button" href="/parent/consent">
            Give consent again
          </Link>
        )}
      </div>
    </section>
  );
}
