---
title: Eliminate N+1 Queries with Batch Loading
impact: MEDIUM-HIGH
impactDescription: 10-100x fewer database round trips
tags: n-plus-one, batch, performance, queries
---

## Eliminate N+1 Queries with Batch Loading

N+1 queries execute one query per item in a loop. Batch them into a single query using arrays or JOINs.

**Incorrect (N+1 queries):**

```sql
-- First query: get all customers
select id from tenant.customer where active = true;  -- Returns 100 IDs

-- Then N queries, one per customer
select * from tenant.order where customer_id = 'uuid-1';
select * from tenant.order where customer_id = 'uuid-2';
select * from tenant.order where customer_id = 'uuid-3';
-- ... 97 more queries!

-- Total: 101 round trips to database
```

**Correct (single batch query):**

```sql
-- Collect IDs and query once with ANY
select * from tenant.order
where customer_id = any($1::uuid[])
  and deleted_at is null;

-- Or use JOIN instead of loop
select c.id, c.name, o.*
from tenant.customer c
left join tenant.order o on o.customer_id = c.id and o.deleted_at is null
where c.active = true and c.deleted_at is null;

-- Total: 1 round trip
```

Application pattern with POG:

```gleam
// Instead of looping:
// list.map(customers, fn(c) { get_orders(db, c.id) })

// Pass array parameter:
// select * from tenant.order where customer_id = any($1::uuid[])
pog.query("select * from tenant.order where customer_id = any($1::uuid[]) and deleted_at is null")
|> pog.parameter(pog.array(customer_ids, pog.text))
|> pog.returning(order_decoder)
|> pog.execute(db)
```

Reference: [Query Optimization](https://www.postgresql.org/docs/current/performance-tips.html)
