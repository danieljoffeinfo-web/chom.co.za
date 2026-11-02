import assert from 'node:assert/strict';
import { test } from 'node:test';

import { isServerOnlyKey } from '../src/keys.ts';

// Builds a JWT-shaped key (header.payload.signature) with the given claims, using
// base64url like real Supabase keys.
function jwt(claims: unknown): string {
  const encode = (value: unknown) => Buffer.from(JSON.stringify(value)).toString('base64url');
  return `${encode({ alg: 'HS256', typ: 'JWT' })}.${encode(claims)}.signature`;
}

test('rejects new-style secret keys', () => {
  assert.equal(isServerOnlyKey('sb_secret_abc123'), true);
});

test('rejects legacy service_role keys', () => {
  assert.equal(isServerOnlyKey(jwt({ iss: 'supabase', role: 'service_role' })), true);
});

test('rejects legacy service_role keys whose payload needs base64 padding', () => {
  // Payload lengths that are not a multiple of 3 bytes produce unpadded base64url.
  for (const ref of ['a', 'ab', 'abc', 'abcd']) {
    assert.equal(isServerOnlyKey(jwt({ ref, role: 'service_role' })), true, ref);
  }
});

test('accepts new-style publishable keys', () => {
  assert.equal(isServerOnlyKey('sb_publishable_abc123'), false);
});

test('accepts legacy anon keys', () => {
  assert.equal(isServerOnlyKey(jwt({ iss: 'supabase', role: 'anon' })), false);
});

test('treats malformed or non-JWT keys as not server-only', () => {
  for (const key of [
    '',
    'not-a-key',
    'a.b.c',
    'a..c',
    'x.%%%.y',
    jwt('just a string'),
    jwt([1, 2]),
  ]) {
    assert.equal(isServerOnlyKey(key), false, key);
  }
});
