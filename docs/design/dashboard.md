# Dashboard design spec

The learner, staff and parent dashboards are one product, so they share one look. The learner dashboard (`static/site/app/index.html`) is the design source; the staff dashboard (`apps/staff`) and the parent dashboard (`apps/web`, under `/parent`) use a copy of its styles from `packages/dashboard`.

## Where the styles live

| File                                 | What it is                                                                                                                                                                           |
| ------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `packages/tokens/tokens.css`         | Colours, radius and spacing for every app. Light by default; `data-theme="dark"` on `<html>` switches to dark.                                                                       |
| `static/site/app/index.html`         | The learner dashboard, the design source.                                                                                                                                            |
| `packages/dashboard/dashboard.css`   | A copy of the learner dashboard's styles. Its colour names (`--bg`, `--ink` and so on) point at `@chom/tokens`.                                                                      |
| `packages/dashboard/app.css`         | Additions every Next.js dashboard needs: form sign-out, empty and coming-soon states, loading skeletons.                                                                             |
| `packages/dashboard/icons.svg`       | The learner dashboard's icons (Heroicons 2.2, MIT), used as `<Icon name="home" />`. Each app serves them at `/icons.svg`. After editing, run `pnpm --filter @chom/dashboard sprite`. |
| `apps/staff/src/app/staff.css`       | The few additions the staff dashboard needs. Keep it short.                                                                                                                          |
| `apps/web/src/app/parent/parent.css` | The few additions the parent dashboard needs: the bottom dock on phones, the sibling switcher, the consent screen.                                                                   |

When the learner dashboard's styles change, copy the change into `packages/dashboard/dashboard.css` too.

## Colour

Navy and vanilla, with no orange. Light mode is the default; dark mode is opt-in from Settings.

| Role         | Light     | Dark      | Token               |
| ------------ | --------- | --------- | ------------------- |
| Background   | `#eeebda` | `#282b4a` | `--chom-background` |
| Card/surface | `#f7f5eb` | `#33375c` | `--chom-surface`    |
| Text         | `#282b4a` | `#eeebda` | `--chom-text`       |
| Muted text   | `#5f6178` | `#aba9b8` | `--chom-text-muted` |
| Lines        | `#dcd8c3` | `#464a70` | `--chom-border`     |
| Soft fill    | `#e4e0cb` | `#3c4068` | `--chom-subtle`     |
| Primary      | `#282b4a` | `#eeebda` | `--chom-primary`    |
| On primary   | `#eeebda` | `#282b4a` | `--chom-on-primary` |

Never write a colour value in app code. Use a token, or a prototype name that maps to one.

## Type

Inter Tight, from Google Fonts (via `next/font` in the apps). Base size 14px.

- Page hero (`.cd-title`): very large, heavy, tight letter spacing. "Hey, Amara." / "Good morning, Sizwe."
- Small caps label above a heading (`.cd-label`): the section name, e.g. "My Classes".
- Section heading (`.cd-head h2`): "Your classes" / "What you teach".

## Layout

- **Sidebar** (`.sidebar`, 248px): wordmark, school card, a labelled main navigation, a secondary navigation (Settings), then Sign out and a footer line at the bottom. Below 900px it becomes a slide-in menu with a dimmed overlay.
- **Quick-actions dock** (`.quick-actions`): floating at the bottom right; on small screens it holds the menu button.
- **Page** (`.page`): up to 1500px wide. Dashboard home pages use `.cd`, which is up to 1180px.
- **Other pages** start with `.view-header` (an `h1` and one line of intro).

## Components

| Component      | Class                                                | Used for                                              |
| -------------- | ---------------------------------------------------- | ----------------------------------------------------- |
| Hero and stats | `.cd-top`, `.cd-hero`, `.cd-stats`, `.cd-stat`       | Greeting, date, and two headline numbers              |
| Section        | `.cd-section`, `.cd-head`                            | A labelled block with an optional "See all" link      |
| Class card     | `.cd-classes`, `.cd-class`, `.cd-avatar`, `.cd-next` | One subject and class                                 |
| Panel          | `.panel`, `.panel-head`                              | Lists and tables                                      |
| Content card   | `.content-card`                                      | Settings and single blocks of content                 |
| Notice         | `.notice`, `.info-strip`                             | One line of context, e.g. what's coming               |
| Empty state    | `.empty-message`                                     | Nothing here yet, and coming soon                     |
| Buttons        | `.button`, `.button.secondary`, `.text-button`       | Actions and "See all" links                           |
| Switch         | `.switch-row`                                        | A setting with a label, a line of help and a checkbox |

## Navigation

| Learner dashboard                                                                     | Staff dashboard                                                      | Parent dashboard                                     |
| ------------------------------------------------------------------------------------- | -------------------------------------------------------------------- | ---------------------------------------------------- |
| Dashboard, My subjects, Study with Chom, My tasks, Assignments, My results, Timetable | Today, My Classes, Set Work, Calendar, Analytics, Messages, Co-pilot | Home, Academics, Sport, Future, Messages (per child) |
| School life, Messages, Settings                                                       | Settings                                                             | Account                                              |

The parent dashboard is mobile-first: below 900px the sidebar is hidden and the five sections move into the bottom dock. A sibling switcher sits at the top of every page and keeps the parent in the same section when they switch child.

## Writing

Plain, warm and short. Say what something does for the person, not how it works. Pages that aren't built yet say "Coming soon" and list, in a line each, what they will do.
