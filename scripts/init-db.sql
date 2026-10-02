-- Initialize database for local development
-- Creates the tasks schema that Ptah will manage
-- Creates a non-superuser app role for RLS enforcement

CREATE SCHEMA IF NOT EXISTS tasks;

-- App role: non-superuser so RLS policies are enforced
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'tasks_app') THEN
    CREATE ROLE tasks_app LOGIN PASSWORD 'tasks_app';
  END IF;
END $$;

-- Grant schema and table access to the app role
GRANT USAGE ON SCHEMA tasks TO tasks_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA tasks GRANT ALL ON TABLES TO tasks_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA tasks GRANT ALL ON SEQUENCES TO tasks_app;
