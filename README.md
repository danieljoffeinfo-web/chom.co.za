# Chom Learn

One platform for students, teachers and parents across many schools. This repository is a monorepo: every app and shared package lives here, managed with [pnpm](https://pnpm.io) workspaces and [Turborepo](https://turborepo.com).

## Layout

```
apps/
  web/                  Next.js web app: teacher dashboard, school admin,
                        and the web version for students and parents
  mobile/               Expo (React Native) app for iOS and Android: one app,
                        the signed-in person's role picks the experience
  site/                 Live static site: public home page (/) and the
                        student prototype (/app/). Deployed to chom.co.za
  teacher-prototype/    Static teacher prototype (design reference only)
packages/
  api/                  Typed Supabase client and query helpers shared by
                        web and mobile (`@chom/api`)
  tokens/               Design tokens: colours, type, spacing, radius.
                        TypeScript for mobile, tokens.css for web
  tsconfig/             Shared TypeScript settings
  prototype-data/       Sample data used only by the static prototypes
supabase/
  migrations/           PostgreSQL schema, helpers and row-level security
  tests/                pgTAP policy tests (school isolation and roles)
  seed.sql              Local demo school (Class 10B) and role users
docs/
  decisions/            Architecture decision records (start with 0001)
scripts/
  build.mjs             Builds the static site and prototypes into dist/
```

Coming next: wire sign-in screens to Supabase Auth, generate `packages/api` types from a linked project, and add Edge Functions for AI, notifications and the Ednana sync.

## Getting started

Requires Node 22+ and pnpm 10 (`corepack enable` installs the right version). For the database locally you also need the [Supabase CLI](https://supabase.com/docs/guides/local-development/cli/getting-started) and Docker.

```bash
pnpm install
cp .env.example .env.local   # then fill keys after supabase start
pnpm db:start                # optional until you work on data
```

| Command | What it does |
|---|---|
| `pnpm dev:web` | Run the web app at http://localhost:3000 |
| `pnpm dev:mobile` | Start Expo. Open on a phone with Expo Go, or an iOS/Android simulator |
| `pnpm typecheck` | Type-check every package |
| `pnpm lint` | Lint, including the design-token drift check |
| `pnpm build` | Production build of the web app |
| `pnpm build:site` | Build the static site into `dist/` (no install needed) |
| `pnpm db:start` | Start local Supabase (API on :54321) |
| `pnpm db:reset` | Re-apply migrations and seed |
| `pnpm db:test` | Run pgTAP RLS tests against the local database |

Seeded local users (password `password`): `teacher@chom.local`, `student@chom.local`, `parent@chom.local`.

## Design tokens

`packages/tokens` is the single source of truth for the Chom look: navy `#282B4A` as the main colour, vanilla `#EEEBDA` as the background, Inter Tight, light mode by default and dark mode opt-in.

- Mobile imports the values directly: `import { colors, space } from '@chom/tokens'`.
- Web imports `@chom/tokens/tokens.css` and uses the `--chom-*` CSS variables.
- `pnpm lint` fails if `tokens.css` and `src/index.ts` disagree, so change both together.

## Data layer

`supabase/` holds the managed Postgres schema (see ADR 0001). Every school-scoped table carries `school_id`, and RLS policies enforce membership and role in the database.

`packages/api` (`@chom/api`) is the typed client both apps import:

```ts
import { createChomClient, listAccessibleClassSubjects } from '@chom/api';
```

Web and mobile wrappers live at `apps/web/src/lib/supabase.ts` and `apps/mobile/src/lib/supabase.ts`. They read `NEXT_PUBLIC_SUPABASE_*` or `EXPO_PUBLIC_SUPABASE_*` from the environment.

## Deployments

| What | Where | How |
|---|---|---|
| Static site (home page + student prototype) | chom.co.za (Vercel project `chom-co-za`) | Root `vercel.json`: skips dependency install, runs `node scripts/build.mjs`, serves `dist/student` |
| Teacher prototype | Vercel project `chom-teacher` | Same build, output directory `dist/teacher` |
| Web app | Not deployed yet | Will be a new Vercel project with Root Directory `apps/web` |
| Mobile app | Not published yet | Will be built and submitted with Expo EAS |
| Database | Not provisioned yet | Managed Supabase project per environment (ADR 0001) |

## Checks

GitHub Actions (`.github/workflows/ci.yml`) runs on every pull request and every push to `main`:

- App job: install, type check, lint, web build, iOS and Android bundles, and the static site build.
- Database job: start local Supabase, reset migrations + seed, run pgTAP RLS tests.

## Prototype notes

The static site and teacher prototype use sample data only. Changes are stored in the browser (localStorage and IndexedDB) and do not sync. The teacher prototype links to the student prototype at `/student/app/#subjects` so both can show shared browser-only state.
