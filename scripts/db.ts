#!/usr/bin/env -S deno run --allow-run --allow-env
/**
 * Ptah Compat database schema management wrapper
 *
 * Automatically fetches DATABASE_URL_SESSION from Google Secret Manager,
 * or uses the environment variable if set.
 *
 * Usage:
 *   deno task db:apply   # Apply schema changes
 *   deno task db:diff    # Show planned changes
 *   deno task db:seed    # Insert default data
 */

const APP_NAME = "tasks";
const SCHEMA_NAME = "tasks";
const GCP_PROJECT = "mklv-infrastructure";
const DEV_DATABASE_URL_SESSION =
  "postgres://tasks:tasks@localhost:5432/tasks?search_path=tasks&sslmode=disable";

async function getDatabaseUrl(): Promise<string> {
  // Check environment variable first
  const envUrl = Deno.env.get("DATABASE_URL_SESSION");
  if (envUrl) {
    console.log("Using DATABASE_URL_SESSION from environment");
    return envUrl;
  }

  // In local dev (no DENO_ENV=production), use default local URL
  if (Deno.env.get("DENO_ENV") !== "production") {
    console.log("Using local dev database URL");
    return DEV_DATABASE_URL_SESSION;
  }

  // Fetch app config JSON from Secret Manager
  console.log("Fetching DATABASE_URL_SESSION from Secret Manager...");
  const secretName = `${APP_NAME}-config`;

  const command = new Deno.Command("gcloud", {
    args: [
      "secrets",
      "versions",
      "access",
      "latest",
      `--secret=${secretName}`,
      `--project=${GCP_PROJECT}`,
    ],
    stdout: "piped",
    stderr: "piped",
  });

  const { code, stdout, stderr } = await command.output();

  if (code !== 0) {
    const errorMsg = new TextDecoder().decode(stderr);
    console.error(`Failed to fetch secret: ${errorMsg}`);
    console.error(
      "\nMake sure you're authenticated with gcloud and have access to the secret.",
    );
    Deno.exit(1);
  }

  const secrets = JSON.parse(new TextDecoder().decode(stdout));
  const url = secrets.DATABASE_URL_SESSION;
  if (!url) {
    console.error(
      "DATABASE_URL_SESSION not found in secret JSON. Available keys:",
      Object.keys(secrets).join(", "),
    );
    Deno.exit(1);
  }

  return url;
}

async function runPtah(
  subcommand: string,
  databaseUrl: string,
): Promise<void> {
  const repoRoot = new URL("../", import.meta.url).pathname;
  const schemaFile = `${repoRoot}db/schema.hcl`;

  const args = [
    "schema",
    "apply",
    "--to",
    `file://${schemaFile}`,
    "--url",
    databaseUrl,
    "--schema",
    SCHEMA_NAME,
    "--var",
    `app_role=${
      Deno.env.get("DENO_ENV") === "production" ? "tasks-role" : "tasks_app"
    }`,
  ];

  // Use the same plan for preview and apply.
  if (subcommand === "apply") {
    args.push("--auto-approve");
  } else {
    args.push("--dry-run");
  }

  console.log(
    `Running: ptah-compat schema apply${
      subcommand === "diff" ? " --dry-run" : ""
    }\n`,
  );

  const command = new Deno.Command("ptah-compat", {
    args,
    stdout: "inherit",
    stderr: "inherit",
  });

  const { code } = await command.output();

  if (code !== 0) {
    Deno.exit(code);
  }
}

async function runTruncate(databaseUrl: string): Promise<void> {
  console.log("Dropping all tables in schema (Ptah will recreate them)...\n");

  const sql = `
DO $$
DECLARE
  tbl text;
  tables text[] := ARRAY['task_history', 'task_contexts', 'recurrence_rules',
                         'saved_filters', 'tasks', 'context_time_windows',
                         'contexts', 'projects'];
BEGIN
  FOREACH tbl IN ARRAY tables
  LOOP
    IF EXISTS (SELECT 1 FROM information_schema.tables
               WHERE table_schema = '${SCHEMA_NAME}' AND table_name = tbl) THEN
      EXECUTE format('DROP TABLE %I.%I CASCADE', '${SCHEMA_NAME}', tbl);
      RAISE NOTICE 'Dropped: %.%', '${SCHEMA_NAME}', tbl;
    END IF;
  END LOOP;
END $$;
`;

  const psqlUrl = databaseUrl.split("?")[0];
  const command = new Deno.Command("psql", {
    args: [psqlUrl, "-c", sql],
    stdout: "inherit",
    stderr: "inherit",
  });

  const { code } = await command.output();

  if (code !== 0) {
    Deno.exit(code);
  }

  console.log("\nAll tables dropped successfully.");
}

async function runSeed(databaseUrl: string): Promise<void> {
  console.log("Seeding default data...\n");

  // Dev user UUID must match the dev bypass in src/middleware.ts
  const DEV_USER_ID = "00000000-0000-0000-0000-000000000001";

  // Insert default "work" context with Mon-Fri 9am-5pm time windows
  const sql = `
-- Set app.user_id so RLS INSERT policies pass
SET LOCAL app.user_id = '${DEV_USER_ID}';

-- Create default work context if it doesn't exist
INSERT INTO ${SCHEMA_NAME}.contexts (id, user_id, name)
VALUES ('00000000-0000-0000-0000-000000000001', '${DEV_USER_ID}', 'work')
ON CONFLICT DO NOTHING;

-- Create time windows for Mon-Fri (days 1-5)
INSERT INTO ${SCHEMA_NAME}.context_time_windows (context_id, day_of_week, start_time, end_time)
SELECT '00000000-0000-0000-0000-000000000001', day, '09:00'::time, '17:00'::time
FROM generate_series(1, 5) AS day
ON CONFLICT DO NOTHING;

SELECT 'Seeded default work context' AS status;
`;

  const psqlUrl = databaseUrl.split("?")[0];
  const command = new Deno.Command("psql", {
    args: [psqlUrl, "-c", sql],
    stdout: "inherit",
    stderr: "inherit",
  });

  const { code } = await command.output();

  if (code !== 0) {
    Deno.exit(code);
  }

  console.log("\nSeed data inserted successfully.");
}

export async function main(args: string[] = Deno.args): Promise<void> {
  const subcommand = args[0];

  if (
    !subcommand ||
    !["apply", "diff", "truncate", "seed"].includes(subcommand)
  ) {
    console.log("Usage: db.ts <apply|diff|truncate|seed>");
    console.log("");
    console.log("Commands:");
    console.log("  apply     Apply schema changes to the database");
    console.log("  diff      Show planned schema changes without applying");
    console.log(
      "  truncate  Truncate all tables (use before destructive migrations)",
    );
    console.log("  seed      Insert default data (work context)");
    Deno.exit(1);
  }

  const databaseUrl = await getDatabaseUrl();

  if (subcommand === "truncate") {
    await runTruncate(databaseUrl);
  } else if (subcommand === "seed") {
    await runSeed(databaseUrl);
  } else {
    await runPtah(subcommand, databaseUrl);
  }
}

if (import.meta.main) {
  await main();
}
