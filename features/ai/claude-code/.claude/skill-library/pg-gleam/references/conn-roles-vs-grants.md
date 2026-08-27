---
title: Roles Are Cluster-Level, Grants Are Per-Database
impact: MEDIUM
impactDescription: Test failures after DB drop/recreate - missing grants
tags: roles, grants, permissions, testing, database-lifecycle
---

## Roles Are Cluster-Level, Grants Are Per-Database

PostgreSQL roles are created at the cluster level (shared across all databases), but GRANT statements apply per-database. After `DROP DATABASE` + `CREATE DATABASE`, the role still exists but all grants are lost.

**Incorrect (grants wrapped in role creation check):**

```gleam
// Test setup function
pub fn ensure_rls_test_role(db: Connection) -> Result(Nil, Error) {
  let check_role = "
    SELECT 1 FROM pg_roles WHERE rolname = 'kafka_app_test'
  "

  case pog.execute(check_role, db, [], row_decoder) {
    Ok([]) -> {
      // Role doesn't exist - create it AND grant permissions
      pog.execute("CREATE ROLE kafka_app_test", db, [], unit_decoder)
      pog.execute("GRANT USAGE ON SCHEMA tenant TO kafka_app_test", db, [], unit_decoder)
      pog.execute("GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA tenant TO kafka_app_test", db, [], unit_decoder)
    }
    Ok(_) -> {
      // Role exists - SKIP grants!
      // BUG: After DB drop+recreate, role exists (cluster-level)
      //      but grants were lost (per-database)
      Ok(Nil)
    }
  }
}

// Test fails: "permission denied for schema tenant"
```

**Correct (separate role creation from grants):**

```gleam
pub fn ensure_rls_test_role(db: Connection) -> Result(Nil, Error) {
  // Step 1: Create role if it doesn't exist (cluster-level check)
  let check_role = "
    SELECT 1 FROM pg_roles WHERE rolname = 'kafka_app_test'
  "

  case pog.execute(check_role, db, [], row_decoder) {
    Ok([]) -> {
      // Create role - only runs once per cluster
      pog.execute("CREATE ROLE kafka_app_test", db, [], unit_decoder)
    }
    Ok(_) -> Ok(Nil)  // Role exists
    Error(e) -> Error(e)
  }

  // Step 2: ALWAYS re-apply grants (per-database)
  // These need to run after every CREATE DATABASE
  use _ <- result.try(
    pog.execute("GRANT USAGE ON SCHEMA tenant TO kafka_app_test", db, [], unit_decoder)
  )
  use _ <- result.try(
    pog.execute("GRANT USAGE ON SCHEMA core TO kafka_app_test", db, [], unit_decoder)
  )
  use _ <- result.try(
    pog.execute("GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA tenant TO kafka_app_test", db, [], unit_decoder)
  )
  use _ <- result.try(
    pog.execute("GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA core TO kafka_app_test", db, [], unit_decoder)
  )

  Ok(Nil)
}
```

**psql Manual Setup:**

```sql
-- Check if role exists (cluster-level)
SELECT rolname FROM pg_roles WHERE rolname = 'kafka_app_test';

-- Create role if missing (only needs to run once per cluster)
CREATE ROLE kafka_app_test;

-- Grant permissions (must run for EACH database)
\c kafka_test
GRANT USAGE ON SCHEMA tenant, core TO kafka_app_test;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA tenant TO kafka_app_test;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA core TO kafka_app_test;

\c kafka_dev
GRANT USAGE ON SCHEMA tenant, core TO kafka_app_test;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA tenant TO kafka_app_test;
-- Repeat for each database
```

**Why This Matters:**

- `DROP DATABASE` doesn't drop roles (they're cluster-level)
- `CREATE DATABASE` starts with blank permissions
- Test suite using cached role assumption fails
- Production database restores need grant re-application

**Rule:** Separate role creation (conditional, cluster-level check) from grants (always re-apply, per-database). Grants must run after every `CREATE DATABASE`, regardless of role existence.

**Source:** Kafka lessons.md (2026-02-14 PR #145)

Reference: [PostgreSQL Roles](https://www.postgresql.org/docs/current/user-manag.html)
