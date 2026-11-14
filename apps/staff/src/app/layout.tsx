import '@chom/tokens/tokens.css';
import '@chom/dashboard/dashboard.css';
import '@chom/dashboard/app.css';
import './staff.css';
import type { Metadata, Viewport } from 'next';
import { Inter_Tight } from 'next/font/google';
import type { ReactNode } from 'react';

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
  themeColor: '#0a0a0a',
  colorScheme: 'dark',
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en-ZA" data-theme="dark" className={interTight.variable}>
      <body>{children}</body>
    </html>
  );
}
