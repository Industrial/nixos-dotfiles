---
title: Use Connection Pooling for All Applications
impact: CRITICAL
impactDescription: Handle 10-100x more concurrent users
tags: connection-pooling, pog, performance, scalability
---

## Use Connection Pooling for All Applications

Postgres connections are expensive (1-3MB RAM each). Without pooling, applications exhaust connections under load.

**Incorrect (new connection per request):**

```sql
-- Each request creates a new connection
-- Result: 500 concurrent users = 500 connections = crashed database

-- Check current connections
select count(*) from pg_stat_activity;  -- 487 connections!
```

**Correct (POG built-in connection pooling):**

POG (Gleam's Postgres driver) includes a built-in connection pool using the binary protocol. No external pooler needed.

```gleam
// Configure pool size in your Gleam application
pog.default_config()
|> pog.host("localhost")
|> pog.database("myapp")
|> pog.pool_size(10)  // (CPU cores * 2) + spindle_count
|> pog.connect
```

```sql
-- Result: 500 concurrent users share 10 actual connections
select count(*) from pg_stat_activity;  -- 10 connections
```

**POG connection pool characteristics:**

- **Binary protocol**: Uses Postgres extended query protocol, more efficient than text protocol
- **No external pooler**: No PgBouncer/pgpool needed in front of the database
- **Direct connections**: Each pool connection is a real Postgres connection (supports prepared statements, temp tables, session variables)
- **Session variables**: `set_local` works correctly since each request gets a real connection for the transaction

**Pool sizing guideline:**

```
pool_size = (CPU cores * 2) + number_of_disks
```

For a 4-core server with SSD: `pool_size = 10`

For multiple application instances, divide the pool across them:

```
total_pool = (CPU cores * 2) + disks
per_instance = total_pool / number_of_instances
```

Reference: [POG](https://hexdocs.pm/pog/)
