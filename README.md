# Chom Learn

One platform for students, teachers and parents across many schools. This repository is a monorepo: every app and shared package lives here, managed with [pnpm](https://pnpm.io) workspaces and [Turborepo](https://turborepo.com).

## Layout

```
apps/                   Workspace apps (every folder here is picked up automatically)
  web/                  Next.js web app: teacher dashboard, school admin,
                        and the web version for students and parents
  mobile/               Expo (React Native) app for iOS and Android: one app,
                        the signed-in person's role picks the experience
packages/               Shared workspace packages (picked up automatically)
  tokens/               Design tokens: colours, type, spacing, radius.
                        TypeScript for mobile, tokens.css for web
  tsconfig/             Shared TypeScript settings
static/                 No-build HTML, outside the workspace, deployed as-is
  site/                 Live static site: public home page (/) and the
                        student prototype (/app/). Deployed to chom.co.za
  teacher-prototype/    Static teacher prototype (design reference only)
  prototype-data/       Sample data used only by the static prototypes
docs/
  decisions/            Architecture decision records (start with 0001)
scripts/
  build.mjs             Builds static/ into dist/
  vercel-ignore.sh      Skips chom.co.za deploys when static/ didn't change
```

To add a shared package, create a folder under `packages/` with a `package.json` named `@chom/<name>`. No other registration is needed.

Coming next: `supabase/` (database migrations, row-level security and their tests) and `packages/api` (one typed data client shared by web and mobile).

## Getting started

Requires Node 22+ and pnpm 10 (`corepack enable` installs the right version).

```bash
pnpm install
```

| Command             | What it does                                                                 |
| ------------------- | ---------------------------------------------------------------------------- |
| `pnpm dev:web`      | Run the web app at http://localhost:3000                                     |
| `pnpm dev:mobile`   | Start Expo. Open on a phone with Expo Go, or an iOS/Android simulator        |
| `pnpm typecheck`    | Type-check every package                                                     |
| `pnpm lint`         | ESLint for web and mobile (no warnings allowed), plus the design-token check |
| `pnpm format`       | Format everything with Prettier                                              |
| `pnpm format:check` | Check formatting without changing files (what CI runs)                       |
| `pnpm build`        | Production build of the web app                                              |
| `pnpm build:site`   | Build the static site into `dist/` (no install needed)                       |

ESLint fails if code imports a package its own `package.json` doesn't list. `node_modules` is flat (Expo needs this), so without that rule an undeclared package would quietly work locally and break elsewhere.

## Secrets and environment files

Never commit `.env` files. Every `.env` and `.env.*` file is ignored by git, and CI fails if one is force-added. To document which settings an app needs, commit a `.env.example` next to it with the variable names and no real values.

## Design tokens

`packages/tokens` is the single source of truth for the Chom look: navy `#282B4A` as the main colour, vanilla `#EEEBDA` as the background, Inter Tight, light mode by default and dark mode opt-in.

- Mobile imports the values directly: `import { colors, space } from '@chom/tokens'`.
- Web imports `@chom/tokens/tokens.css` and uses the `--chom-*` CSS variables.
- `pnpm lint` fails if `tokens.css` and `src/index.ts` disagree, so change both together.

## Deployments

| What                                        | Where                                    | How                                                                                                                                                                                                  |
| ------------------------------------------- | ---------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Static site (home page + student prototype) | chom.co.za (Vercel project `chom-co-za`) | Root `vercel.json`: skips dependency install, runs `node scripts/build.mjs`, serves `dist/student`. Skips the deploy when nothing in `static/` or its build changed since the last successful deploy |
| Teacher prototype                           | Vercel project `chom-teacher`            | Same build, output directory `dist/teacher`                                                                                                                                                          |
| Web app                                     | Not deployed yet                         | Will be a new Vercel project with Root Directory `apps/web`                                                                                                                                          |
| Mobile app                                  | Not published yet                        | Will be built and submitted with Expo EAS                                                                                                                                                            |

## Checks

GitHub Actions (`.github/workflows/ci.yml`) runs on every pull request and every push to `main`, with a read-only token:

1. No `.env` files committed
2. Install from the lockfile
3. Formatting (Prettier)
4. Type check
5. Lint (ESLint and the design-token check)
6. Web build
7. iOS and Android bundles
8. Static site build

Mobile images and fonts can be imported with either `import logo from './logo.png'` or `require('./logo.png')`. The types for both are committed in `apps/mobile/src/types/assets.d.ts`, so they type-check in CI as well as locally.

## Prototype notes

The static site and teacher prototype use sample data only. Changes are stored in the browser (localStorage and IndexedDB) and do not sync. The teacher prototype links to the student prototype at `/student/app/#subjects` so both can show shared browser-only state.
