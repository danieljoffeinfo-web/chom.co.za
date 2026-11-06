import { cache } from 'react';

import { createClient } from '../supabase/server';
import { loadGuardianLinks, loadParentContext } from './parent';

/**
 * The signed-in parent and their links for this request. Cached per request, so the
 * layout and the page share one set of database calls.
 */
export const currentParent = cache(async () => loadParentContext(await createClient()));
export const currentLinks = cache(async () => loadGuardianLinks(await createClient()));

/** The child with this profile id, if the parent may see them. */
export async function findChild(childId: string) {
  const parent = await currentParent();
  const child = parent?.children.find((c) => c.id === childId) ?? null;
  return { parent, child };
}
