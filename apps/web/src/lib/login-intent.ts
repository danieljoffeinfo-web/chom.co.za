/**
 * Which door someone signed in through: the Teacher login, the Parent login, or the
 * normal one. It's remembered in a short-lived cookie between asking for the email
 * link and clicking it, so the link can send someone with more than one role (a
 * teacher who is also a parent, say) to the dashboard they asked for. Without it,
 * people go to the dashboard for the role they have.
 */
export const LOGIN_AS_COOKIE = 'chom-login-as';

export type LoginAs = 'staff' | 'parent' | 'learner';

export function parseLoginAs(value: string | undefined | null): LoginAs {
  return value === 'staff' || value === 'parent' ? value : 'learner';
}

/** The `as` query parameter for a door, for building links: `?as=parent`, or none. */
export function loginAsParam(loginAs: LoginAs, separator: '?' | '&' = '?'): string {
  return loginAs === 'learner' ? '' : `${separator}as=${loginAs}`;
}
