import '@chom/dashboard/dashboard.css';
import '@chom/dashboard/app.css';
import './parent.css';
import type { ReactNode } from 'react';

/** Every parent page uses the shared dashboard look (packages/dashboard). */
export default function ParentLayout({ children }: { children: ReactNode }) {
  return children;
}
