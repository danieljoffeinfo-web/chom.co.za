// Builds src/sprite.ts from icons.svg, so every app can serve the same icons at
// /icons.svg without copying files. Run `pnpm --filter @chom/dashboard sprite` after
// changing icons.svg. With --check (lint and test), fails if sprite.ts is out of date
// or the Icon component's names don't match the sprite.
import { createHash } from 'node:crypto';
import { readFile, writeFile } from 'node:fs/promises';

const svg = await readFile(new URL('../icons.svg', import.meta.url), 'utf8');
const out = new URL('../src/sprite.ts', import.meta.url);

const generated = `// Generated from icons.svg by scripts/sprite.mjs. Do not edit by hand.
// Heroicons v2.2.0 (MIT, Tailwind Labs); the licence is kept in icons.svg.

export const ICON_SPRITE = ${JSON.stringify(svg)};
`;

// Browsers cache /icons.svg for a day, so <Icon> asks for /icons.svg?v=<hash>: a changed
// sprite gets a new URL and new icons show at once. Kept apart from sprite.ts so the
// client bundle carries the hash, not the whole sprite.
const versionOut = new URL('../src/sprite-version.ts', import.meta.url);
const version = createHash('sha256').update(svg).digest('hex').slice(0, 10);
const versionGenerated = `// Generated from icons.svg by scripts/sprite.mjs. Do not edit by hand.
export const ICON_SPRITE_VERSION = '${version}';
`;

if (process.argv.includes('--check')) {
  let failures = 0;
  const current = await readFile(out, 'utf8').catch(() => '');
  const currentVersion = await readFile(versionOut, 'utf8').catch(() => '');
  if (current !== generated || currentVersion !== versionGenerated) {
    console.error('src/sprite.ts is out of date. Run: pnpm --filter @chom/dashboard sprite');
    failures++;
  }
  const inSprite = new Set([...svg.matchAll(/<symbol id="i-([a-z-]+)"/g)].map((m) => m[1]));
  const icon = await readFile(new URL('../src/icon.tsx', import.meta.url), 'utf8');
  const named = [...icon.matchAll(/\| '([a-z-]+)'/g)].map((m) => m[1]);
  for (const name of named) {
    if (!inSprite.has(name)) {
      console.error(`IconName '${name}' has no <symbol id="i-${name}"> in icons.svg`);
      failures++;
    }
  }
  process.exit(failures ? 1 : 0);
} else {
  await writeFile(out, generated);
  await writeFile(versionOut, versionGenerated);
  console.log('Wrote src/sprite.ts and src/sprite-version.ts');
}
