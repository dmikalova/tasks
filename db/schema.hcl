# Database schema for tasks
# Managed by Ptah Compat - https://ptah.run

schema "tasks" {}

# Enums

enum "schedule_type" {
  schema = schema.tasks

  values = ["fixed", "completion"]
}

enum "frequency" {
  schema = schema.tasks

  values = ["daily", "weekly", "monthly", "yearly"]
}

enum "task_action" {
  schema = schema.tasks

  values = [
    "created",
    "updated",
    "completed",
    "uncompleted",
    "deferred",
    "undeferred",
    "deleted"
  ]
}

# Tables

table "projects" {
  schema = schema.tasks

  row_security {
    enabled  = true
    enforced = true
  }

  column "id" {
    type    = uuid
    null    = false
    default = sql("gen_random_uuid()")
  }

  column "user_id" {
    type = uuid
    null = false
  }

  column "name" {
    type = text
    null = false
  }

  column "description" {
    type = text
    null = true
  }

  column "color" {
    type = text
    null = true
  }

  column "parent_project_id" {
    type = uuid
    null = true
  }

  column "sort_order" {
    type    = integer
    null    = false
    default = 0
  }

  column "created_at" {
    type    = timestamptz
    null    = false
    default = sql("now()")
  }

  primary_key {
    columns = [column.id]
  }

  foreign_key "fk_parent_project" {
    columns     = [column.parent_project_id]
    ref_columns = [table.projects.column.id]
    on_delete   = SET_NULL
  }

  index "idx_projects_user_id" {
    columns = [column.user_id]
  }

  index "idx_projects_user_id_name" {
    columns = [column.user_id, column.name]
    unique  = true
  }

  index "idx_projects_parent_project_id" {
    columns = [column.parent_project_id]
  }

}

table "contexts" {
  schema = schema.tasks

  row_security {
    enabled  = true
    enforced = true
  }

  column "id" {
    type    = uuid
    null    = false
    default = sql("gen_random_uuid()")
  }

  column "user_id" {
    type = uuid
    null = false
  }

  column "name" {
    type = text
    null = false
  }

  column "color" {
    type = text
    null = true
  }

  column "sort_order" {
    type    = integer
    null    = false
    default = 0
  }

  column "created_at" {
    type    = timestamptz
    null    = false
    default = sql("now()")
  }

  primary_key {
    columns = [column.id]
  }

  index "idx_contexts_user_id" {
    columns = [column.user_id]
  }

}

table "context_time_windows" {
  schema = schema.tasks

  row_security {
    enabled  = true
    enforced = true
  }

  column "id" {
    type    = uuid
    null    = false
    default = sql("gen_random_uuid()")
  }

  column "context_id" {
    type = uuid
    null = false
  }

  # 0=Sunday, 6=Saturday
  column "day_of_week" {
    type = integer
    null = false
  }

  column "start_time" {
    type = time
    null = false
  }

  column "end_time" {
    type = time
    null = false
  }

  primary_key {
    columns = [column.id]
  }

  foreign_key "fk_context" {
    columns     = [column.context_id]
    ref_columns = [table.contexts.column.id]
    on_delete   = CASCADE
  }

  index "idx_context_time_windows_context_id" {
    columns = [column.context_id]
  }

  check "valid_day_of_week" {
    expr = "day_of_week >= 0 AND day_of_week <= 6"
  }

  check "valid_time_range" {
    expr = "start_time < end_time"
  }

}

table "tasks" {
  schema = schema.tasks

  row_security {
    enabled  = true
    enforced = true
  }

  column "id" {
    type    = uuid
    null    = false
    default = sql("gen_random_uuid()")
  }

  column "user_id" {
    type = uuid
    null = false
  }

  column "title" {
    type = text
    null = false
  }

  column "project_id" {
    type = uuid
    null = true
  }

  # 1-4 priority, higher = more important
  column "priority" {
    type    = integer
    null    = false
    default = 2
  }

  column "due_date" {
    type = date
    null = true
  }

  column "deferred_until" {
    type = timestamptz
    null = true
  }

  column "completed_at" {
    type = timestamptz
    null = true
  }

  # Soft delete flag
  column "deleted_at" {
    type = timestamptz
    null = true
  }

  column "created_at" {
    type    = timestamptz
    null    = false
    default = sql("now()")
  }

  column "updated_at" {
    type    = timestamptz
    null    = false
    default = sql("now()")
  }

  primary_key {
    columns = [column.id]
  }

  foreign_key "fk_project" {
    columns     = [column.project_id]
    ref_columns = [table.projects.column.id]
    on_delete   = SET_NULL
  }

  index "idx_tasks_project_id" {
    columns = [column.project_id]
  }

  index "idx_tasks_due_date" {
    columns = [column.due_date]
  }

  index "idx_tasks_completed_at" {
    columns = [column.completed_at]
  }

  index "idx_tasks_user_id" {
    columns = [column.user_id]
  }

  index "idx_tasks_deleted_at" {
    columns = [column.deleted_at]
  }

  check "valid_priority" {
    expr = "priority >= 1 AND priority <= 4"
  }

  check "valid_title_length" {
    expr = "length(title) <= 500"
  }

}

table "recurrence_rules" {
  schema = schema.tasks

  row_security {
    enabled  = true
    enforced = true
  }

  column "id" {
    type    = uuid
    null    = false
    default = sql("gen_random_uuid()")
  }

  column "task_id" {
    type = uuid
    null = false
  }

  # 'fixed' or 'completion'
  column "schedule_type" {
    type = enum.schedule_type
    null = false
  }

  # For fixed schedules: 'daily', 'weekly', 'monthly', 'yearly'
  column "frequency" {
    type = enum.frequency
    null = true
  }

  # Every N days/weeks/months/years
  column "interval" {
    type    = integer
    null    = false
    default = 1
  }

  # [0-6] for weekly (0=Sunday)
  column "days_of_week" {
    type = sql("integer[]")
    null = true
  }

  # 1-31 for monthly
  column "day_of_month" {
    type = integer
    null = true
  }

  # 1-12 for yearly
  column "month_of_year" {
    type = integer
    null = true
  }

  # For completion-based schedules
  column "days_after_completion" {
    type = integer
    null = true
  }

  column "created_at" {
    type    = timestamptz
    null    = false
    default = sql("now()")
  }

  primary_key {
    columns = [column.id]
  }

  foreign_key "fk_task" {
    columns     = [column.task_id]
    ref_columns = [table.tasks.column.id]
    on_delete   = CASCADE
  }

  index "idx_recurrence_rules_task_id" {
    columns = [column.task_id]
  }

  # Ensure only one rule per task
  index "idx_recurrence_rules_task_unique" {
    columns = [column.task_id]
    unique  = true
  }

  check "valid_interval" {
    expr = "interval >= 1"
  }

  check "valid_day_of_month" {
    expr = "day_of_month IS NULL OR (day_of_month >= 1 AND day_of_month <= 31)"
  }

  check "valid_month_of_year" {
    expr = "month_of_year IS NULL OR (month_of_year >= 1 AND month_of_year <= 12)"
  }

  check "valid_days_after_completion" {
    expr = "days_after_completion IS NULL OR days_after_completion >= 1"
  }

  # Fixed schedules require frequency
  check "fixed_requires_frequency" {
    expr = "schedule_type::text != 'fixed' OR frequency IS NOT NULL"
  }

  # Completion-based schedules require days_after_completion
  check "completion_requires_days" {
    expr = "schedule_type::text != 'completion' OR days_after_completion IS NOT NULL"
  }

}

table "saved_filters" {
  schema = schema.tasks

  row_security {
    enabled  = true
    enforced = true
  }

  column "id" {
    type    = uuid
    null    = false
    default = sql("gen_random_uuid()")
  }

  column "user_id" {
    type = uuid
    null = false
  }

  column "name" {
    type = text
    null = false
  }

  column "color" {
    type = text
    null = true
  }

  # JSON filter definition
  column "filter" {
    type = jsonb
    null = false
  }

  column "created_at" {
    type    = timestamptz
    null    = false
    default = sql("now()")
  }

  primary_key {
    columns = [column.id]
  }

  index "idx_saved_filters_user_id" {
    columns = [column.user_id]
  }

}

table "task_history" {
  schema = schema.tasks

  row_security {
    enabled  = true
    enforced = true
  }

  column "id" {
    type    = uuid
    null    = false
    default = sql("gen_random_uuid()")
  }

  column "user_id" {
    type = uuid
    null = false
  }

  column "task_id" {
    type = uuid
    null = false
  }

  column "action" {
    type = enum.task_action
    null = false
  }

  # Action-specific data (old value, new value, etc.)
  column "details" {
    type = jsonb
    null = true
  }

  column "created_at" {
    type    = timestamptz
    null    = false
    default = sql("now()")
  }

  primary_key {
    columns = [column.id]
  }

  foreign_key "fk_task" {
    columns     = [column.task_id]
    ref_columns = [table.tasks.column.id]
    on_delete   = CASCADE
  }

  index "idx_task_history_task_id" {
    columns = [column.task_id]
  }

  index "idx_task_history_user_id" {
    columns = [column.user_id]
  }

  index "idx_task_history_created_at" {
    columns = [column.created_at]
  }

}

table "project_contexts" {
  schema = schema.tasks

  column "project_id" {
    type = uuid
    null = false
  }

  column "context_id" {
    type = uuid
    null = false
  }

  primary_key {
    columns = [column.project_id, column.context_id]
  }

  foreign_key "fk_project" {
    columns     = [column.project_id]
    ref_columns = [table.projects.column.id]
    on_delete   = CASCADE
  }

  foreign_key "fk_context" {
    columns     = [column.context_id]
    ref_columns = [table.contexts.column.id]
    on_delete   = CASCADE
  }

  index "idx_project_contexts_context_id" {
    columns = [column.context_id]
  }

}

table "task_contexts" {
  schema = schema.tasks

  column "task_id" {
    type = uuid
    null = false
  }

  column "context_id" {
    type = uuid
    null = false
  }

  primary_key {
    columns = [column.task_id, column.context_id]
  }

  foreign_key "fk_task" {
    columns     = [column.task_id]
    ref_columns = [table.tasks.column.id]
    on_delete   = CASCADE
  }

  foreign_key "fk_context" {
    columns     = [column.context_id]
    ref_columns = [table.contexts.column.id]
    on_delete   = CASCADE
  }

  index "idx_task_contexts_context_id" {
    columns = [column.context_id]
  }

}

table "user_next_selection" {
  schema = schema.tasks

  column "user_id" {
    type = uuid
    null = false
  }

  column "task_id" {
    type = uuid
    null = true
  }

  column "selected_at" {
    type    = timestamptz
    null    = false
    default = sql("now()")
  }

  primary_key {
    columns = [column.user_id]
  }

  foreign_key "fk_task" {
    columns     = [column.task_id]
    ref_columns = [table.tasks.column.id]
    on_delete   = SET_NULL
  }

}

table "user_settings" {
  schema = schema.tasks

  row_security {
    enabled  = true
    enforced = true
  }

  column "user_id" {
    type = uuid
    null = false
  }

  column "timezone" {
    type    = text
    null    = false
    default = "UTC"
  }

  column "updated_at" {
    type    = timestamptz
    null    = false
    default = sql("now()")
  }

  primary_key {
    columns = [column.user_id]
  }
}

# Row-level security
# Set app.user_id in each transaction before accessing application data.

policy "projects_user_select" {
  on    = table.projects
  for   = SELECT
  using = "user_id = current_setting('app.user_id')::uuid"
}

policy "projects_user_insert" {
  on    = table.projects
  for   = INSERT
  check = "user_id = current_setting('app.user_id')::uuid"
}

policy "projects_user_update" {
  on    = table.projects
  for   = UPDATE
  using = "user_id = current_setting('app.user_id')::uuid"
  check = "user_id = current_setting('app.user_id')::uuid"
}

policy "projects_user_delete" {
  on    = table.projects
  for   = DELETE
  using = "user_id = current_setting('app.user_id')::uuid"
}

policy "contexts_user_select" {
  on    = table.contexts
  for   = SELECT
  using = "user_id = current_setting('app.user_id')::uuid"
}

policy "contexts_user_insert" {
  on    = table.contexts
  for   = INSERT
  check = "user_id = current_setting('app.user_id')::uuid"
}

policy "contexts_user_update" {
  on    = table.contexts
  for   = UPDATE
  using = "user_id = current_setting('app.user_id')::uuid"
  check = "user_id = current_setting('app.user_id')::uuid"
}

policy "contexts_user_delete" {
  on    = table.contexts
  for   = DELETE
  using = "user_id = current_setting('app.user_id')::uuid"
}

policy "ctw_user_select" {
  on    = table.context_time_windows
  for   = SELECT
  using = "EXISTS (SELECT 1 FROM tasks.contexts WHERE id = context_id AND user_id = current_setting('app.user_id')::uuid)"
}

policy "ctw_user_insert" {
  on    = table.context_time_windows
  for   = INSERT
  check = "EXISTS (SELECT 1 FROM tasks.contexts WHERE id = context_id AND user_id = current_setting('app.user_id')::uuid)"
}

policy "ctw_user_update" {
  on    = table.context_time_windows
  for   = UPDATE
  using = "EXISTS (SELECT 1 FROM tasks.contexts WHERE id = context_id AND user_id = current_setting('app.user_id')::uuid)"
  check = "EXISTS (SELECT 1 FROM tasks.contexts WHERE id = context_id AND user_id = current_setting('app.user_id')::uuid)"
}

policy "ctw_user_delete" {
  on    = table.context_time_windows
  for   = DELETE
  using = "EXISTS (SELECT 1 FROM tasks.contexts WHERE id = context_id AND user_id = current_setting('app.user_id')::uuid)"
}

policy "tasks_user_select" {
  on    = table.tasks
  for   = SELECT
  using = "user_id = current_setting('app.user_id')::uuid"
}

policy "tasks_user_insert" {
  on    = table.tasks
  for   = INSERT
  check = "user_id = current_setting('app.user_id')::uuid"
}

policy "tasks_user_update" {
  on    = table.tasks
  for   = UPDATE
  using = "user_id = current_setting('app.user_id')::uuid"
  check = "user_id = current_setting('app.user_id')::uuid"
}

policy "tasks_user_delete" {
  on    = table.tasks
  for   = DELETE
  using = "user_id = current_setting('app.user_id')::uuid"
}

policy "recurrence_user_select" {
  on    = table.recurrence_rules
  for   = SELECT
  using = "EXISTS (SELECT 1 FROM tasks.tasks WHERE id = task_id AND user_id = current_setting('app.user_id')::uuid)"
}

policy "recurrence_user_insert" {
  on    = table.recurrence_rules
  for   = INSERT
  check = "EXISTS (SELECT 1 FROM tasks.tasks WHERE id = task_id AND user_id = current_setting('app.user_id')::uuid)"
}

policy "recurrence_user_update" {
  on    = table.recurrence_rules
  for   = UPDATE
  using = "EXISTS (SELECT 1 FROM tasks.tasks WHERE id = task_id AND user_id = current_setting('app.user_id')::uuid)"
  check = "EXISTS (SELECT 1 FROM tasks.tasks WHERE id = task_id AND user_id = current_setting('app.user_id')::uuid)"
}

policy "recurrence_user_delete" {
  on    = table.recurrence_rules
  for   = DELETE
  using = "EXISTS (SELECT 1 FROM tasks.tasks WHERE id = task_id AND user_id = current_setting('app.user_id')::uuid)"
}

policy "saved_filters_user_select" {
  on    = table.saved_filters
  for   = SELECT
  using = "user_id = current_setting('app.user_id')::uuid"
}

policy "saved_filters_user_insert" {
  on    = table.saved_filters
  for   = INSERT
  check = "user_id = current_setting('app.user_id')::uuid"
}

policy "saved_filters_user_update" {
  on    = table.saved_filters
  for   = UPDATE
  using = "user_id = current_setting('app.user_id')::uuid"
  check = "user_id = current_setting('app.user_id')::uuid"
}

policy "saved_filters_user_delete" {
  on    = table.saved_filters
  for   = DELETE
  using = "user_id = current_setting('app.user_id')::uuid"
}

policy "task_history_user_select" {
  on    = table.task_history
  for   = SELECT
  using = "user_id = current_setting('app.user_id')::uuid"
}

policy "task_history_user_insert" {
  on    = table.task_history
  for   = INSERT
  check = "user_id = current_setting('app.user_id')::uuid"
}

policy "task_history_user_update" {
  on    = table.task_history
  for   = UPDATE
  using = "user_id = current_setting('app.user_id')::uuid"
  check = "user_id = current_setting('app.user_id')::uuid"
}

policy "task_history_user_delete" {
  on    = table.task_history
  for   = DELETE
  using = "user_id = current_setting('app.user_id')::uuid"
}

policy "user_settings_user_select" {
  on    = table.user_settings
  for   = SELECT
  using = "user_id = current_setting('app.user_id')::uuid"
}

policy "user_settings_user_insert" {
  on    = table.user_settings
  for   = INSERT
  check = "user_id = current_setting('app.user_id')::uuid"
}

policy "user_settings_user_update" {
  on    = table.user_settings
  for   = UPDATE
  using = "user_id = current_setting('app.user_id')::uuid"
  check = "user_id = current_setting('app.user_id')::uuid"
}

policy "user_settings_user_delete" {
  on    = table.user_settings
  for   = DELETE
  using = "user_id = current_setting('app.user_id')::uuid"
}

# The database bootstrap owns role creation; this schema manages its access.
variable "app_role" {
  type    = string
  default = "tasks_app"
}

permission {
  to         = var.app_role
  for        = schema.tasks
  privileges = [USAGE]
}

permission {
  to         = var.app_role
  for        = table.projects
  privileges = [SELECT, INSERT, UPDATE, DELETE]
}

permission {
  to         = var.app_role
  for        = table.contexts
  privileges = [SELECT, INSERT, UPDATE, DELETE]
}

permission {
  to         = var.app_role
  for        = table.context_time_windows
  privileges = [SELECT, INSERT, UPDATE, DELETE]
}

permission {
  to         = var.app_role
  for        = table.tasks
  privileges = [SELECT, INSERT, UPDATE, DELETE]
}

permission {
  to         = var.app_role
  for        = table.recurrence_rules
  privileges = [SELECT, INSERT, UPDATE, DELETE]
}

permission {
  to         = var.app_role
  for        = table.saved_filters
  privileges = [SELECT, INSERT, UPDATE, DELETE]
}

permission {
  to         = var.app_role
  for        = table.task_history
  privileges = [SELECT, INSERT, UPDATE, DELETE]
}

permission {
  to         = var.app_role
  for        = table.project_contexts
  privileges = [SELECT, INSERT, UPDATE, DELETE]
}

permission {
  to         = var.app_role
  for        = table.task_contexts
  privileges = [SELECT, INSERT, UPDATE, DELETE]
}

permission {
  to         = var.app_role
  for        = table.user_next_selection
  privileges = [SELECT, INSERT, UPDATE, DELETE]
}

permission {
  to         = var.app_role
  for        = table.user_settings
  privileges = [SELECT, INSERT, UPDATE, DELETE]
}
