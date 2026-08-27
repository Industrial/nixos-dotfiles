---
title: Understand Prepared Statements with POG
impact: HIGH
impactDescription: Correct mental model for how POG handles query preparation
tags: prepared-statements, pog, binary-protocol, extended-query
---

## Understand Prepared Statements with POG

POG uses the Postgres **extended query protocol** with binary encoding. This is fundamentally different from named prepared statements in other drivers.

**How POG works (extended query protocol):**

```
-- POG sends queries using the extended query protocol:
-- 1. Parse: SQL with $1, $2 placeholders
-- 2. Bind: Binary-encoded parameter values
-- 3. Execute: Run the bound statement
-- All in a single protocol exchange
```

This means:

- **No named prepared statements**: POG doesn't use `PREPARE`/`EXECUTE` SQL commands
- **No pooler conflicts**: No risk of "prepared statement does not exist" errors
- **Binary encoding**: Parameters and results use efficient binary format (not text)
- **Automatic type handling**: Postgres handles type coercion via the protocol

**Setting session variables with POG:**

Since POG gives you real connections (not transaction-mode pooled), session variables work correctly:

```sql
-- Set at the start of each request within a transaction
set_local app.current_tenant_id = $1;
set_local app.current_user_id = $2;

-- These persist for the duration of the transaction
-- and are automatically cleared when the transaction ends
```

**Parameterized queries in POG:**

```gleam
// POG handles parameterization via the binary protocol
// No SQL injection risk, no manual escaping
let assert Ok(rows) =
  pog.query("select * from tenant.order where tenant_id = $1 and status = $2")
  |> pog.parameter(pog.text(tenant_id))
  |> pog.parameter(pog.text(status))
  |> pog.returning(order_decoder)
  |> pog.execute(db)
```

Reference: [Extended Query Protocol](https://www.postgresql.org/docs/current/protocol-flow.html#PROTOCOL-FLOW-EXT-QUERY)
