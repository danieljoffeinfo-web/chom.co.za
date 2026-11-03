import assert from 'node:assert/strict';
import { test } from 'node:test';

import { AUTH_COOKIE_NAME, authCookieOptions } from '../src/auth-cookies.ts';

test('chom.co.za and staff.chom.co.za share one sign-in cookie', () => {
  for (const host of ['chom.co.za', 'staff.chom.co.za', 'STAFF.chom.co.za', 'chom.co.za:443']) {
    assert.deepEqual(authCookieOptions(host), { name: AUTH_COOKIE_NAME, domain: 'chom.co.za' });
  }
});

test('previews, localhost and look-alike domains keep the cookie to themselves', () => {
  for (const host of [
    'chom-staff.vercel.app',
    'localhost:3001',
    'notchom.co.za',
    null,
    undefined,
  ]) {
    assert.deepEqual(authCookieOptions(host), { name: AUTH_COOKIE_NAME });
  }
});
