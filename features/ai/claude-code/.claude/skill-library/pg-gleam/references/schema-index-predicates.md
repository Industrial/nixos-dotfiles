---
title: Index Predicates Require IMMUTABLE Functions
impact: HIGH
impactDescription: Index creation failures for time-based partial indexes
tags: indexes, partial-indexes, immutability, functions, schema-design
---

## Index Predicates Require IMMUTABLE Functions

PostgreSQL partial index predicates (WHERE clauses) must use IMMUTABLE functions only. Time-based functions like `now()`, `current_timestamp`, and `CURRENT_DATE` are STABLE (can vary within a transaction), not IMMUTABLE, and cannot be used in index predicates.

**Incorrect (index creation fails):**

```sql
-- Attempting to create index with now() predicate
CREATE UNIQUE INDEX idx_active_sessions ON sessions (user_id)
WHERE expires_at > now();

-- ERROR: functions in index predicate must be marked IMMUTABLE
-- now() is STABLE - can return different values within same transaction
```

**Correct (handle expiry in application code):**

```sql
-- Create index without time-based predicate
CREATE UNIQUE INDEX idx_sessions_user ON sessions (user_id);

-- Check expiry in query WHERE clause (not in index predicate)
SELECT * FROM sessions
WHERE user_id = $1
  AND expires_at > now();

-- Application-level check is flexible and works correctly
```

**Alternative: Boolean Flag Pattern**

```sql
-- Add explicit is_active column updated by trigger or application
ALTER TABLE sessions ADD COLUMN is_active boolean DEFAULT true;

-- Index on boolean flag (IMMUTABLE)
CREATE UNIQUE INDEX idx_active_sessions ON sessions (user_id)
WHERE is_active = true;

-- Update flag when session expires (via trigger or cron job)
UPDATE sessions SET is_active = false
WHERE expires_at < now() AND is_active = true;
```

**Why This Matters:**

- Index predicates are evaluated at index BUILD time and INSERT time
- Time-based predicates would require constant index rebuilding
- IMMUTABLE constraint ensures index remains consistent
- Application-level filtering is more flexible anyway

**Rule:** Cannot use `now()`, `CURRENT_TIMESTAMP`, `CURRENT_DATE`, or any STABLE/VOLATILE functions in index predicates. Handle time-based filtering in application queries or use boolean flags.

**Source:** Kafka lessons.md (2026-02-10 PR #51)

Reference: [PostgreSQL Index Predicates](https://www.postgresql.org/docs/current/indexes-partial.html)
