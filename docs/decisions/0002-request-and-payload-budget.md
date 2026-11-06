# ADR 0002: One read per screen, and no extra origins

| | |
|---|---|
| **Status** | Accepted |
| **Date** | 3 November 2026 |
| **Decision owner** | Engineering |
| **Applies to** | The public site, the prototypes, the web and mobile apps, and every later data client |
| **Review by** | With [ADR 0001](0001-database-platform.md), or when the first database-backed screen ships |

---

## 1. Summary

Each phase of Chom Learn keeps the number of network round trips small. South African schools sit about 150–180 ms from a European database, and school networks drop out. A screen that looks fast on a laptop in the same city can still feel slow if it waits on Google, or on three database calls in a row.

This record does not add a database, a cache, or a load balancer. Those arrive with the work in ADR 0001. It says how that work has to behave.

## 2. What ships today

- The public site and the learner prototype self-host Inter Tight. They do not call `fonts.googleapis.com` or `fonts.gstatic.com`.
- The learner prototype stays one HTML document. Splitting its CSS and script into extra files would add round trips for a page that is already one response.
- `school.js` loads at the end of the page, after the shell is parsed, and teacher and learner still share that one file.
- Font files are cached for a year. HTML stays revalidated.
- The mobile app loads four Inter Tight weights. It does not import the package barrel, which would ship every weight and italic.
- The Next.js app already self-hosts its font through `next/font`. Vercel’s edge serves the public site. There is no separate load balancer to add.

## 3. Rules for the database phase

When `supabase/` and `packages/api` exist, every screen follows these rules. ADR 0001 already sets the capacity target and the order of scaling: tune queries, then a larger instance, then read replicas, then a cache of non-personal data.

- **One data read per screen.** A screen that needs tasks, the class and the teacher loads them in one query or one database function, not three calls one after another. Lists select only the columns that screen renders.
- **Indexed filters.** Every school-scoped query filters on an indexed `school_id`, plus the other columns in the `WHERE`. The app does not download a table and filter it.
- **Realtime only while messages are open.** A live connection is not left open on the home screen, the timetable or a task list.
- **What may be cached where.** Public pages and font files stay on the Vercel CDN. Personal data (names, marks, messages, attendance) is not stored in a shared CDN. The school-day screens may keep a copy on the device, so a dropped connection or the extra European round trip does not blank the page.
- **Pooling, not another proxy.** The first hosted database uses Supavisor, the connection pooler named in ADR 0001. Read replicas wait until queries are tuned and one larger instance is not enough. A separate load balancer is not part of this phase.

## 4. How to check a change

Before a screen or a query is merged:

1. Count the requests the screen makes on a cold load, including fonts and data. Add a request only when the bytes cannot travel with a request that already exists.
2. For a database screen, show the query (or the single function call) and the index it uses.
3. Confirm personal data is not given a shared cache header.
