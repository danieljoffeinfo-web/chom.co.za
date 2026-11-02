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
  tokens/               Design tokens: colours, type, spacing, radius.
                        TypeScript for mobile, tokens.css for web
  tsconfig/             Shared TypeScript settings
  prototype-data/       Sample data used only by the static prototypes
docs/
  decisions/            Architecture decision records (start with 0001)
scripts/
  build.mjs             Builds the static site and prototypes into dist/
```

Coming next: `supabase/` (database migrations, row-level security and their tests) and `packages/api` (one typed data client shared by web and mobile).

## Getting started

Requires Node 22+ and pnpm 10 (`corepack enable` installs the right version).

```bash
pnpm install
```

| Command | What it does |
|---|---|
| `pnpm dev:web` | Run the web app at http://localhost:3000 |
| `pnpm dev:mobile` | Start Expo. Open on a phone with Expo Go, or an iOS/Android simulator |
| `pnpm typecheck` | Type-check every package |
| `pnpm lint` | Lint, including the design-token drift check |
| `pnpm build` | Production build of the web app |
| `pnpm build:site` | Build the static site into `dist/` (no install needed) |

## Design tokens

`packages/tokens` is the single source of truth for the Chom look: navy `#282B4A` as the main colour, vanilla `#EEEBDA` as the background, Inter Tight, light mode by default and dark mode opt-in.

- Mobile imports the values directly: `import { colors, space } from '@chom/tokens'`.
- Web imports `@chom/tokens/tokens.css` and uses the `--chom-*` CSS variables.
- `pnpm lint` fails if `tokens.css` and `src/index.ts` disagree, so change both together.

## Deployments

| What | Where | How |
|---|---|---|
| Static site (home page + student prototype) | chom.co.za (Vercel project `chom-co-za`) | Root `vercel.json`: skips dependency install, runs `node scripts/build.mjs`, serves `dist/student` |
| Teacher prototype | Vercel project `chom-teacher` | Same build, output directory `dist/teacher` |
| Web app | Not deployed yet | Will be a new Vercel project with Root Directory `apps/web` |
| Mobile app | Not published yet | Will be built and submitted with Expo EAS |

## Checks

GitHub Actions (`.github/workflows/ci.yml`) runs on every pull request and every push to `main`: install, type check, lint, web build, iOS and Android bundles, and the static site build.

## Prototype notes

The static site and teacher prototype use sample data only. Changes are stored in the browser (localStorage and IndexedDB) and do not sync. The teacher prototype links to the student prototype at `/student/app/#subjects` so both can show shared browser-only state.
