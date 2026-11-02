import type { ChomClient } from '../client';
import type { TableRow } from '../database.types';

export type School = TableRow<'schools'>;
export type SchoolMembership = TableRow<'school_memberships'>;

/** Schools the signed-in person belongs to (RLS filters the rest). */
export async function listMySchools(client: ChomClient) {
  return client.from('schools').select('*').order('name');
}

/** Membership rows for one person (usually the signed-in user). */
export async function listMyMemberships(client: ChomClient, personId: string) {
  return client.from('school_memberships').select('*').eq('person_id', personId);
}
