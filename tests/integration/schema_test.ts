// Exercise the migration wrapper against the same disposable database as the
// integration suite. Role creation remains the database bootstrap's responsibility.
import { assertEquals, assertStringIncludes } from "@std/assert";
import { createTestDb } from "./setup.ts";

const databaseUrl = Deno.env.get("TEST_DATABASE_URL") ||
  "postgres://tasks:tasks@localhost:5432/tasks";

async function runSchema(command: "apply" | "diff"): Promise<string> {
  const result = await new Deno.Command(Deno.execPath(), {
    args: ["run", "--permission-set=scripts", "scripts/db.ts", command],
    env: { DATABASE_URL_SESSION: databaseUrl, DENO_ENV: "development" },
    stdout: "piped",
    stderr: "piped",
  }).output();
  assertEquals(result.code, 0, new TextDecoder().decode(result.stderr));
  return new TextDecoder().decode(result.stdout);
}

Deno.test("schema apply restores RLS drift without a separate SQL step", async () => {
  const db = createTestDb();
  try {
    const original = await db`
      SELECT qual FROM pg_policies
      WHERE schemaname = 'tasks' AND tablename = 'projects'
        AND policyname = 'projects_user_select'
    `;
    assertEquals(original.length, 1);

    await db`ALTER POLICY projects_user_select ON tasks.projects USING (false)`;
    await db`ALTER TABLE tasks.projects NO FORCE ROW LEVEL SECURITY`;

    const preview = await runSchema("diff");
    assertStringIncludes(preview, "projects_user_select");
    assertStringIncludes(preview, "FORCE ROW LEVEL SECURITY");
    const unchanged = await db`
      SELECT qual FROM pg_policies
      WHERE schemaname = 'tasks' AND tablename = 'projects'
        AND policyname = 'projects_user_select'
    `;
    assertEquals(unchanged[0].qual, "false");

    await runSchema("apply");
    const restored = await db`
      SELECT qual FROM pg_policies
      WHERE schemaname = 'tasks' AND tablename = 'projects'
        AND policyname = 'projects_user_select'
    `;
    assertEquals(restored[0].qual, original[0].qual);
    const [flags] = await db`
      SELECT relrowsecurity, relforcerowsecurity FROM pg_class
      WHERE oid = 'tasks.projects'::regclass
    `;
    assertEquals(flags, { relrowsecurity: true, relforcerowsecurity: true });

    const plan = await new Deno.Command("ptah-compat", {
      args: [
        "schema",
        "apply",
        "--url",
        databaseUrl,
        "--to",
        "file://db/schema.hcl",
        "--schema",
        "tasks",
        "--dry-run",
        "--format",
        "{{ json . }}",
      ],
      stdout: "piped",
      stderr: "piped",
    }).output();
    assertEquals(plan.code, 0, new TextDecoder().decode(plan.stderr));
    assertEquals(JSON.parse(new TextDecoder().decode(plan.stdout)).Changes, {});
  } finally {
    try {
      await runSchema("apply");
    } finally {
      await db.end();
    }
  }
});
