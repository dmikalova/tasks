# Tasks App

Conventions specific to this Deno + Hono + Lit web application.

## Commands

| Task                 | Command                         |
| -------------------- | ------------------------------- |
| Dev server           | `deno task dev`                 |
| Type-check           | `deno task check`               |
| Format               | `deno task fmt`                 |
| Lint                 | `deno task lint`                |
| Unit tests           | `deno task test`                |
| All tests + coverage | `deno task test:all --coverage` |
| Integration tests    | `deno task test:integration`    |
| Apply schema (local) | `deno task db:apply`            |
| Apply schema (prod)  | `deno task db:apply`            |
| Schema diff          | `deno task db:diff`             |
| Reset local DB       | `deno task db:reset`            |

## Testing

- Unit tests: `tests/unit/` — no external dependencies
- Integration tests: `tests/integration/` — requires PostgreSQL (via
  `docker compose`) and `ptah-compat` on `PATH`
- Coverage target: 100% line and function coverage
- Run `deno task test:all --coverage` to verify coverage
- Always check for coverage regressions in CI and maintain 100% coverage on new
  code - otherwise the code cannot be committed.
- Coverage reports output to `coverage/` (HTML + lcov)

## Database

- PostgreSQL with schema isolation (`tasks` schema)
- Schema managed by Ptah Compat (`db/schema.hcl`)
- Local dev uses Docker Compose (`compose.yaml`)
- App connects as `tasks_app` (non-superuser) for RLS enforcement
- Migrations applied via `scripts/db.ts`

## Frontend

- Lit web components with m3e design system (`npm:@m3e/web@2`)
- Bundled via esbuild on server startup
- Source in `src/frontend/`
- Components in `src/frontend/components/`
- Reactive store pattern (`src/frontend/store.ts`)
