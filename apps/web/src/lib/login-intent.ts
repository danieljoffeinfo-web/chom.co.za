/**
 * Which door someone signed in through: the Teacher login, or the normal one. It's
 * remembered in a short-lived cookie between asking for the email link and clicking
 * it, so the link can send a teacher who is also on a class list (or a parent) to
 * the right dashboard. Without it, people go to the dashboard for the role they have.
 */
export const LOGIN_AS_COOKIE = 'chom-login-as';

export type LoginAs = 'staff' | 'learner';

export function parseLoginAs(value: string | undefined | null): LoginAs {
  return value === 'staff' ? 'staff' : 'learner';
}
