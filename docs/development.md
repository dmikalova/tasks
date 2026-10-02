# Development

Local development setup for the tasks app.

## Prerequisites

- [Deno](https://deno.land/) 2.0+
- PostgreSQL database (via Supabase or local)
- [Ptah Compat v0.11.4](https://github.com/stokaro/ptah/releases/tag/v0.11.4):
  install `ptah-compat` from the archive for your platform on `PATH`
- `psql` for the existing truncate and seed commands

## Setup

1. Clone the repository
2. Copy environment variables (see `.env.example` when created)
3. Run database migrations: `deno task db:apply`
4. Start the API server: `deno task api:dev`
5. Start the frontend: `deno task src:dev`

## Database schema

`db/schema.hcl` declares tables, row-level security policies, and application
permissions together. `deno task db:diff` previews the same plan that
`deno task db:apply` applies. Both use Ptah Compat; there is no separate RLS SQL
step after apply.

The local database bootstrap still creates `tasks_app`. Production still uses
its existing `tasks-role`; setting `DENO_ENV=production` selects that role for
permissions. The schema does not create or change role credentials. For direct
CLI use against production, pass `--var app_role=tasks-role`.

The former `db/rls.sql` policies are now HCL declarations with the same names,
conditions, commands, and ENABLE/FORCE settings. Table and schema grants are
also declarative. The schema has no sequences, so the old grant on all existing
sequences had no objects to grant on.

To check the migration workflow and RLS enforcement against a disposable local
database:

```bash
deno task db:apply
deno task db:diff
deno task test:all --coverage
```

The schema integration test changes a policy and its FORCE setting, confirms
that preview leaves the database unchanged, then verifies that apply restores
both and that the next plan is empty. Run integration tests only against a test
database.

## Environment Variables

| Variable                   | Description               |
| -------------------------- | ------------------------- |
| `DATABASE_URL_TRANSACTION` | PostgreSQL connection URL |
| `SUPABASE_URL`             | Supabase project URL      |
| `SUPABASE_PUBLISHABLE_KEY` | Supabase publishable key  |
| `SUPABASE_JWT_KEY`         | JWT secret for validation |

## Testing

```bash
# Run unit tests
deno task test

# Run all tests (requires database)
deno task test:all
```
