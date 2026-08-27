---
title: Use Cursor-Based Pagination Instead of OFFSET
impact: MEDIUM-HIGH
impactDescription: Consistent O(1) performance regardless of page depth
tags: pagination, cursor, keyset, offset, performance
---

## Use Cursor-Based Pagination Instead of OFFSET

OFFSET-based pagination scans all skipped rows, getting slower on deeper pages. Cursor pagination is O(1).

**Incorrect (OFFSET pagination):**

```sql
-- Page 1: scans 20 rows
select * from tenant.product order by created_at desc, id desc limit 20 offset 0;

-- Page 100: scans 2000 rows to skip 1980
select * from tenant.product order by created_at desc, id desc limit 20 offset 1980;

-- Page 10000: scans 200,000 rows!
select * from tenant.product order by created_at desc, id desc limit 20 offset 199980;
```

**Correct (cursor/keyset pagination with UUIDs):**

```sql
-- Page 1: get first 20
select * from tenant.product
where deleted_at is null
order by created_at desc, id desc
limit 20;
-- Application stores last row's (created_at, id) as cursor

-- Next page: start after the cursor
select * from tenant.product
where deleted_at is null
  and (created_at, id) < ($1, $2)  -- cursor values from last row
order by created_at desc, id desc
limit 20;
-- Uses index, always fast regardless of page depth
```

**Index to support cursor pagination:**

```sql
-- Composite index matching the ORDER BY clause
create index idx_product_cursor on tenant.product (created_at desc, id desc)
  where deleted_at is null;
```

Since UUIDv7 embeds a timestamp, you can often paginate by `id` alone for time-ordered data:

```sql
-- If ordering by creation time, UUIDv7 id alone is sufficient
select * from tenant.product
where deleted_at is null
  and id < $1  -- UUIDv7 is time-ordered, so this works for chronological pagination
order by id desc
limit 20;
```

Reference: [Keyset Pagination](https://use-the-index-luke.com/no-offset)
