// Fails if .env.example drifts from the env keys @chom/api documents.
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../..');
const example = await readFile(path.join(root, '.env.example'), 'utf8');

const required = [
  'NEXT_PUBLIC_SUPABASE_URL',
  'NEXT_PUBLIC_SUPABASE_ANON_KEY',
  'EXPO_PUBLIC_SUPABASE_URL',
  'EXPO_PUBLIC_SUPABASE_ANON_KEY',
];

let failures = 0;
for (const key of required) {
  if (!example.includes(`${key}=`)) {
    console.error(`.env.example is missing ${key}`);
    failures++;
  }
}

if (failures) process.exit(1);
console.log('.env.example lists the public Supabase keys for web and mobile');
