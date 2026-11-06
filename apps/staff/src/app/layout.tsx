import '@chom/tokens/tokens.css';
import '@chom/dashboard/dashboard.css';
import '@chom/dashboard/app.css';
import './staff.css';
import type { Metadata, Viewport } from 'next';
import { Inter_Tight } from 'next/font/google';
import type { ReactNode } from 'react';

import { currentTheme } from '@/lib/theme';

const interTight = Inter_Tight({
  subsets: ['latin'],
  weight: ['400', '500', '600', '700', '800'],
  variable: '--font-inter-tight',
  display: 'swap',
});

export const metadata: Metadata = {
  title: 'Chom Staff',
  description: 'Your classes, your learners and your teaching day, in one place.',
  robots: { index: false, follow: false },
};

export const viewport: Viewport = {
  themeColor: '#eeebda',
};

export default async function RootLayout({ children }: { children: ReactNode }) {
  const theme = await currentTheme();
  return (
    <html lang="en-ZA" data-theme={theme} className={interTight.variable}>
      <body>{children}</body>
    </html>
  );
}
