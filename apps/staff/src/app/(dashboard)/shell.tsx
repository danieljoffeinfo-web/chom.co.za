'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { type ReactNode, useEffect, useState } from 'react';

import { Icon, type IconName } from '@chom/dashboard';

type NavItem = { href: string; label: string; icon: IconName };

const TEACHING: NavItem[] = [
  { href: '/', label: 'Today', icon: 'home' },
  { href: '/classes', label: 'My Classes', icon: 'school' },
  { href: '/set-work', label: 'Set Work', icon: 'file' },
  { href: '/calendar', label: 'Calendar', icon: 'calendar' },
  { href: '/analytics', label: 'Analytics', icon: 'chart' },
  { href: '/messages', label: 'Messages', icon: 'message' },
  { href: '/co-pilot', label: 'Co-pilot', icon: 'spark' },
];

const PREFERENCES: NavItem[] = [{ href: '/settings', label: 'Settings', icon: 'settings' }];

function isActive(path: string, href: string) {
  return href === '/' ? path === '/' : path === href || path.startsWith(`${href}/`);
}

/**
 * The dashboard frame, the same as the learner dashboard: sidebar on the left (a
 * slide-in menu on small screens) and the quick-actions dock.
 */
export function Shell({
  schoolName,
  roleLabel,
  initials,
  name,
  children,
}: {
  schoolName: string;
  roleLabel: string;
  initials: string;
  name: string;
  children: ReactNode;
}) {
  const path = usePathname();
  // The mobile menu is open on the page it was opened on; moving to another page
  // closes it.
  const [menuOpenOn, setMenuOpenOn] = useState<string | null>(null);
  const menuOpen = menuOpenOn === path;
  const setMenuOpen = (open: boolean) => setMenuOpenOn(open ? path : null);

  useEffect(() => {
    if (!menuOpen) return;
    const onKey = (event: KeyboardEvent) => event.key === 'Escape' && setMenuOpenOn(null);
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [menuOpen]);

  const navLinks = (items: NavItem[]) =>
    items.map((item) => {
      const active = isActive(path, item.href);
      return (
        <Link
          key={item.href}
          href={item.href}
          className={active ? 'active' : undefined}
          aria-current={active ? 'page' : undefined}
        >
          <Icon name={item.icon} />
          {item.label}
        </Link>
      );
    });

  return (
    <>
      <a className="skip-link" href="#main">
        Skip to content
      </a>
      <div
        className={menuOpen ? 'overlay open' : 'overlay'}
        onClick={() => setMenuOpen(false)}
        aria-hidden="true"
      />
      <aside
        className={menuOpen ? 'sidebar open' : 'sidebar'}
        id="sidebar"
        aria-label="Main navigation"
      >
        <Link className="brand" href="/" aria-label="Chom Staff home">
          <svg className="brand-mark" viewBox="0 0 40 40" aria-hidden="true">
            <rect x="1" y="1" width="38" height="38" rx="19" fill="#282b4a" />
            <path
              d="M27 12.5a10 10 0 1 0 0 15"
              fill="none"
              stroke="#eeebda"
              strokeWidth="5"
              strokeLinecap="round"
            />
          </svg>
          <span className="wordmark">
            chom<span>staff</span>
          </span>
        </Link>
        <button className="mobile-close" onClick={() => setMenuOpen(false)} aria-label="Close menu">
          <Icon name="x" />
        </button>
        <div className="school-switch">
          <span className="school-icon">
            <Icon name="school" small />
          </span>
          <span>
            <strong>{schoolName}</strong>
            {roleLabel}
          </span>
        </div>
        <p className="nav-label">My teaching</p>
        <nav className="nav" aria-label="Teaching">
          {navLinks(TEACHING)}
        </nav>
        <nav className="nav secondary" aria-label="Preferences">
          {navLinks(PREFERENCES)}
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
            Staff early access
          </div>
        </div>
      </aside>
      <div className="shell">
        <nav className="quick-actions" aria-label="Quick actions">
          <button
            className="quick-button mobile-menu"
            onClick={() => setMenuOpen(true)}
            aria-label="Open menu"
            aria-controls="sidebar"
            aria-expanded={menuOpen}
            data-hint="Menu"
          >
            <Icon name="menu" />
          </button>
          <span className="dock-divider mobile-only" aria-hidden="true" />
          <Link
            className="quick-button"
            href="/settings"
            aria-label={`${name}'s settings`}
            data-hint="Your settings"
          >
            <span className="avatar" aria-hidden="true">
              {initials}
            </span>
          </Link>
        </nav>
        <main className="page" id="main" tabIndex={-1}>
          {children}
        </main>
      </div>
    </>
  );
}
