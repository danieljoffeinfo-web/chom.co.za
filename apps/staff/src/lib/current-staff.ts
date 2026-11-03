import { cache } from 'react';

import { loadStaffContext } from './staff';
import { createClient } from './supabase/server';

/**
 * The signed-in staff member for this request. Cached per request, so the layout and
 * the page share one set of queries.
 */
export const currentStaff = cache(async () => loadStaffContext(await createClient()));
