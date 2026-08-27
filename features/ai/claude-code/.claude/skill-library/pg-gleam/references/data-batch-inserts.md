---
title: Batch INSERT Statements for Bulk Data
impact: MEDIUM
impactDescription: 10-50x faster bulk inserts
tags: batch, insert, bulk, performance, copy
---

## Batch INSERT Statements for Bulk Data

Individual INSERT statements have high overhead. Batch multiple rows in single statements or use COPY.

**Incorrect (individual inserts):**

```sql
-- Each insert is a separate transaction and round trip
insert into tenant.event (tenant_id, user_id, action) values ($1, $2, 'click');
insert into tenant.event (tenant_id, user_id, action) values ($1, $2, 'view');
insert into tenant.event (tenant_id, user_id, action) values ($1, $3, 'click');
-- ... 1000 more individual inserts

-- 1000 inserts = 1000 round trips = slow
```

**Correct (batch insert):**

```sql
-- Multiple rows in single statement
insert into tenant.event (tenant_id, user_id, action) values
  ($1, $2, 'click'),
  ($1, $2, 'view'),
  ($1, $3, 'click'),
  -- ... up to ~1000 rows per batch
  ($1, $4, 'view');

-- One round trip for 1000 rows
```

For large imports, use COPY:

```sql
-- COPY is fastest for bulk loading
copy tenant.event (tenant_id, user_id, action, created_at)
from '/path/to/data.csv'
with (format csv, header true);

-- Or from stdin in application
copy tenant.event (tenant_id, user_id, action) from stdin with (format csv);
a1b2-...,f9e8-...,click
a1b2-...,f9e8-...,view
a1b2-...,c3d4-...,click
\.
```

Reference: [COPY](https://www.postgresql.org/docs/current/sql-copy.html)
