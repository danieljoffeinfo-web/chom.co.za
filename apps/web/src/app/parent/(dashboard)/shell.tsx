'use client';

import { Icon, type IconName } from '@chom/dashboard';
import Link from 'next/link';
import { useParams, usePathname } from 'next/navigation';
import type { ReactNode } from 'react';

import { Logo } from '@/components/logo';

type Kid = { id: string; name: string; initials: string; schoolName: string; detail: string };
type Section = { path: string; label: string; icon: IconName };

/** The five sections of spec §4. Each is per child: /parent/<child>/<section>. */
const SECTIONS: Section[] = [
  { path: '', label: 'Home', icon: 'home' },
  { path: 'academics', label: 'Academics', icon: 'book' },
  { path: 'sport', label: 'Sport', icon: 'ball' },
  { path: 'future', label: 'Future', icon: 'cap' },
  { path: 'messages', label: 'Messages', icon: 'message' },
];

const childHref = (childId: string, section: string) =>
  section ? `/parent/${childId}/${section}` : `/parent/${childId}`;

/**
 * The parent dashboard frame, in the same look as the learner and staff dashboards:
 * sidebar on wide screens; on phones the sections move into the bottom tabs. The
 * sibling switcher sits at the top of every page and keeps you in the same section.
 */
export function ParentShell({
  name,
  initials,
  kids,
  children,
}: {
  name: string;
  initials: string;
  kids: Kid[];
  children: ReactNode;
}) {
  const path = usePathname();
  const params = useParams<{ child?: string }>();
  const current = kids.find((k) => k.id === params.child) ?? kids[0];
  // The section after /parent/<child>/, or '' for Home.
  const section = params.child ? (path.split('/')[3] ?? '') : null;
  const onAccount = path.startsWith('/parent/account');

  const sectionLinks = (className?: string) =>
    SECTIONS.map((s) => {
      const active = section === s.path;
      return current ? (
        <Link
          key={s.label}
          href={childHref(current.id, s.path)}
          className={[className, active ? 'active' : null].filter(Boolean).join(' ') || undefined}
          aria-current={active ? 'page' : undefined}
        >
          <Icon name={s.icon} />
          <span>{s.label}</span>
        </Link>
      ) : null;
    });

  return (
    <>
      <a className="skip-link" href="#main">
        Skip to content
      </a>
      <aside className="sidebar parent-sidebar" id="sidebar" aria-label="Main navigation">
        <Link className="brand" href="/parent" aria-label="Chom Parent home">
          <Logo className="brand-logo" height={30} />
          <span className="brand-tag">parent</span>
        </Link>
        {current && (
          <div className="school-switch">
            <span className="school-icon">
              <Icon name="school" small />
            </span>
            <span>
              <strong>{current.schoolName}</strong>
              {current.detail || 'Parent'}
            </span>
          </div>
        )}
        {current && (
          <>
            <p className="nav-label">{current.name}</p>
            <nav className="nav" aria-label={`${current.name}'s sections`}>
              {sectionLinks()}
            </nav>
          </>
        )}
        <nav className="nav secondary" aria-label="Your account">
          <Link
            href="/parent/account"
            className={onAccount ? 'active' : undefined}
            aria-current={onAccount ? 'page' : undefined}
          >
            <Icon name="user" />
            <span>Account</span>
          </Link>
        </nav>
        <div className="sidebar-bottom">
          <form action="/sign-out" method="post">
            <button className="sign-out" type="submit">
              <svg
                className="icon small"
                viewBox="0 0 20 20"
                fill="none"
                stroke="currentColor"
                strokeWidth="1.8"
                strokeLinecap="round"
                strokeLinejoin="round"
                aria-hidden="true"
              >
                <path d="M8 4H5a1 1 0 0 0-1 1v10a1 1 0 0 0 1 1h3M13 13.5 16.5 10 13 6.5M16.5 10H8" />
              </svg>
              Sign out
            </button>
          </form>
          <div className="sidebar-footer">
            <i />
            Parent early access
          </div>
        </div>
      </aside>
      <div className="shell">
        {current && (
          <nav className="tab-dock" aria-label="Sections">
            {sectionLinks()}
          </nav>
        )}
        <nav className="quick-actions parent-dock" aria-label="Your account">
          <Link
            className={onAccount ? 'quick-button active' : 'quick-button'}
            href="/parent/account"
            aria-label={`${name}'s account`}
            aria-current={onAccount ? 'page' : undefined}
            data-hint="Your account"
          >
            <span className="avatar" aria-hidden="true">
              {initials}
            </span>
          </Link>
        </nav>
        <main className="page" id="main" tabIndex={-1}>
          {kids.length > 0 && (
            <nav className="child-switch" aria-label="Your children">
              {kids.map((k) => {
                const active = !onAccount && k.id === current?.id;
                return (
                  <Link
                    key={k.id}
                    href={childHref(k.id, section ?? '')}
                    className={active ? 'child-chip active' : 'child-chip'}
                    aria-current={active ? 'page' : undefined}
                  >
                    <span className="avatar" aria-hidden="true">
                      {k.initials}
                    </span>
                    <span>
                      <strong>{k.name}</strong>
                      <small>{k.schoolName}</small>
                    </span>
                  </Link>
                );
              })}
            </nav>
          )}
          {children}
        </main>
      </div>
    </>
  );
}
