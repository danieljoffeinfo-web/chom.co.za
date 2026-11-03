'use client';

import { useState } from 'react';

import type { Theme } from '@/lib/theme';

import { saveTheme } from './actions';

export function ThemeSwitch({ initial }: { initial: Theme }) {
  const [theme, setTheme] = useState(initial);

  function onChange(dark: boolean) {
    const next: Theme = dark ? 'dark' : 'light';
    setTheme(next);
    document.documentElement.dataset.theme = next;
    void saveTheme(next);
  }

  return (
    <div className="switch-row">
      <div>
        <label htmlFor="theme-toggle">Dark mode</label>
        <p>Light is the default. Switch on for a navy background.</p>
      </div>
      <input
        type="checkbox"
        id="theme-toggle"
        checked={theme === 'dark'}
        onChange={(event) => onChange(event.target.checked)}
      />
    </div>
  );
}
