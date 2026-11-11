export { createChomClient, type ChomClient, type ChomClientConfig } from './client';
export {
  AUTH_COOKIE_NAME,
  SIGN_IN_ORIGIN,
  STAFF_ORIGIN,
  authCookieOptions,
  staffOriginFor,
} from './auth-cookies';
export { isServerOnlyKey } from './keys';
export { PASSWORD_RULE, passwordProblem } from './password';
export {
  Constants,
  type Database,
  type Enums,
  type Json,
  type Tables,
  type TablesInsert,
  type TablesUpdate,
} from './database.types';

import type { Enums } from './database.types';

/** A person's role at a school: student, teacher, parent or school_admin. */
export type MembershipRole = Enums<'membership_role'>;
