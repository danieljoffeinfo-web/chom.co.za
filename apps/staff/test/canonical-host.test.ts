import assert from 'node:assert/strict';
import { test } from 'node:test';

import { canonicalRedirect, staffSignInUrl } from '../src/lib/canonical-host.ts';

test('production requests on a vercel.app address go to staff.chom.co.za', () => {
  assert.equal(
    canonicalRedirect('chom-staff.vercel.app', '/sign-in?error=link', 'production'),
    'https://staff.chom.co.za/sign-in?error=link',
  );
  assert.equal(
    canonicalRedirect('chom-staff-danieljoffeinfo-1253s-projects.vercel.app', '/', 'production'),
    'https://staff.chom.co.za/',
  );
});

test('requests already on staff.chom.co.za are left alone', () => {
  assert.equal(canonicalRedirect('staff.chom.co.za', '/classes', 'production'), null);
  assert.equal(canonicalRedirect('Staff.Chom.co.za', '/classes', 'production'), null);
});

test('previews, local development and a missing host are left alone', () => {
  assert.equal(canonicalRedirect('chom-staff-git-x.vercel.app', '/', 'preview'), null);
  assert.equal(canonicalRedirect('localhost:3001', '/', undefined), null);
  assert.equal(canonicalRedirect(null, '/', 'production'), null);
});

test('in production, staff sign in through the Teacher login on chom.co.za', () => {
  assert.equal(staffSignInUrl('production'), 'https://chom.co.za/sign-in?as=staff');
  assert.equal(staffSignInUrl('preview'), '/sign-in');
  assert.equal(staffSignInUrl(undefined), '/sign-in');
});
