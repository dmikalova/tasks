import { assertEquals, assertRejects } from "@std/assert";
import { stub } from "@std/testing/mock";
import { main } from "../../scripts/db.ts";

class ScriptExit extends Error {
  constructor(readonly code: number) {
    super(`exit ${code}`);
  }
}

interface Case {
  name: string;
  args: string[];
  env?: Record<string, string>;
  status?: number;
  secret?: Record<string, string>;
  exit?: number;
  commands: string[];
  role?: string;
  planFlag?: string;
}

const cases: Case[] = [
  { name: "help", args: [], exit: 1, commands: [] },
  { name: "unknown command", args: ["invalid"], exit: 1, commands: [] },
  { name: "removed RLS command", args: ["rls"], exit: 1, commands: [] },
  {
    name: "local apply",
    args: ["apply"],
    commands: ["ptah-compat"],
    role: "tasks_app",
    planFlag: "--auto-approve",
  },
  {
    name: "local preview",
    args: ["diff"],
    commands: ["ptah-compat"],
    role: "tasks_app",
    planFlag: "--dry-run",
  },
  {
    name: "explicit URL",
    args: ["apply"],
    env: { DATABASE_URL_SESSION: "postgres://provided/tasks" },
    commands: ["ptah-compat"],
    role: "tasks_app",
    planFlag: "--auto-approve",
  },
  {
    name: "production URL",
    args: ["diff"],
    env: {
      DENO_ENV: "production",
      DATABASE_URL_SESSION: "postgres://provided/tasks",
    },
    commands: ["ptah-compat"],
    role: "tasks-role",
    planFlag: "--dry-run",
  },
  {
    name: "production secret",
    args: ["apply"],
    env: { DENO_ENV: "production" },
    secret: { DATABASE_URL_SESSION: "postgres://secret/tasks" },
    commands: ["gcloud", "ptah-compat"],
    role: "tasks-role",
    planFlag: "--auto-approve",
  },
  {
    name: "secret failure",
    args: ["apply"],
    env: { DENO_ENV: "production" },
    status: 1,
    exit: 1,
    commands: ["gcloud"],
  },
  {
    name: "secret missing URL",
    args: ["apply"],
    env: { DENO_ENV: "production" },
    secret: { OTHER: "value" },
    exit: 1,
    commands: ["gcloud"],
  },
  {
    name: "apply failure",
    args: ["apply"],
    status: 7,
    exit: 7,
    commands: ["ptah-compat"],
  },
  { name: "truncate", args: ["truncate"], commands: ["psql"] },
  {
    name: "truncate failure",
    args: ["truncate"],
    status: 2,
    exit: 2,
    commands: ["psql"],
  },
  { name: "seed", args: ["seed"], commands: ["psql"] },
  {
    name: "seed failure",
    args: ["seed"],
    status: 3,
    exit: 3,
    commands: ["psql"],
  },
];

for (const test of cases) {
  Deno.test(`database wrapper: ${test.name}`, async () => {
    const calls: { command: string; args: string[] }[] = [];
    const envStub = stub(Deno.env, "get", (name) => test.env?.[name]);
    const exitStub = stub(Deno, "exit", (code = 0): never => {
      throw new ScriptExit(code);
    });
    const logStub = stub(console, "log", () => {});
    const errorStub = stub(console, "error", () => {});
    const OriginalCommand = Deno.Command;
    const descriptor = Object.getOwnPropertyDescriptor(Deno, "Command")!;
    class FakeCommand extends OriginalCommand {
      constructor(command: string | URL, options?: Deno.CommandOptions) {
        super(command, options);
        calls.push({ command: String(command), args: options?.args ?? [] });
      }
      override output(): Promise<Deno.CommandOutput> {
        const code = test.status ?? 0;
        return Promise.resolve({
          code,
          success: code === 0,
          signal: null,
          stdout: new TextEncoder().encode(JSON.stringify(test.secret ?? {})),
          stderr: new TextEncoder().encode("command failed"),
        });
      }
    }
    Object.defineProperty(Deno, "Command", {
      ...descriptor,
      get: () => FakeCommand,
    });
    try {
      if (test.exit !== undefined) {
        const error = await assertRejects(() => main(test.args), ScriptExit);
        assertEquals(error.code, test.exit);
      } else {
        await main(test.args);
      }
      assertEquals(calls.map((call) => call.command), test.commands);
      if (test.role) {
        const args = calls.at(-1)!.args;
        assertEquals(args.slice(0, 2), ["schema", "apply"]);
        assertEquals(args[args.indexOf("--var") + 1], `app_role=${test.role}`);
        assertEquals(args.at(-1), test.planFlag);
        assertEquals(
          args[args.indexOf("--url") + 1],
          test.env?.DATABASE_URL_SESSION ?? test.secret?.DATABASE_URL_SESSION ??
            "postgres://tasks:tasks@localhost:5432/tasks?search_path=tasks&sslmode=disable",
        );
      }
    } finally {
      Object.defineProperty(Deno, "Command", descriptor);
      errorStub.restore();
      logStub.restore();
      exitStub.restore();
      envStub.restore();
    }
  });
}
