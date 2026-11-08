// Copies the student dashboard (static/) into the web app's public folder before each
// build:
//   /app/      the student dashboard (where students land after onboarding)
//   /shared/   its subject styles
// The copies are build output (git-ignored); edit the originals in static/.
import { cp, mkdir, readFile, rm, writeFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const web = join(dirname(fileURLToPath(import.meta.url)), '..');
const repo = join(web, '..', '..');
const pub = join(web, 'public');

const copies = [
  ['static/site/app', 'app'],
  ['static/shared', 'shared'],
];

// The teacher prototype was removed; clear any old copy.
await rm(join(pub, 'teacher'), { recursive: true, force: true });

for (const [from, to] of copies) {
  await rm(join(pub, to), { recursive: true, force: true });
  await mkdir(join(pub, to), { recursive: true });
  await cp(join(repo, from), join(pub, to), { recursive: true });
}

// Paths that differ now the dashboard lives inside the app.
async function patch(file, replacements) {
  const path = join(pub, file);
  let html = await readFile(path, 'utf8');
  for (const [from, to] of replacements) html = html.replaceAll(from, to);
  await writeFile(path, html);
}

// "Sign out" really signs out.
await patch('app/index.html', [
  ['class="sign-out" href="../"', 'class="sign-out" href="/sign-out"'],
  ['<a class="button" href="../">Sign out</a>', '<a class="button" href="/sign-out">Sign out</a>'],
]);
console.log('Copied the student dashboard into apps/web/public/{app,shared}');
