---
title: Child Tables Need Their Own tenant_id and RLS
impact: MEDIUM
impactDescription: Reduced defense-in-depth for multi-tenant isolation
tags: rls, multi-tenancy, defense-in-depth, foreign-keys, security
---

## Child Tables Need Their Own tenant_id and RLS

Child tables that cascade from RLS-protected parents should have their own `tenant_id` column and RLS policy for defense-in-depth. Relying solely on parent RLS leaves child tables vulnerable if queried directly.

**Incorrect (child relies on parent RLS only):**

```sql
-- Parent table has RLS
CREATE TABLE tenant.orders (
    id uuid PRIMARY KEY,
    tenant_id uuid NOT NULL REFERENCES core.tenant(id),
    customer_id uuid NOT NULL,
    total bigint NOT NULL
);

ALTER TABLE tenant.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE tenant.orders FORCE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON tenant.orders
    FOR ALL
    USING (tenant_id = (SELECT core.current_tenant_id()))
    WITH CHECK (tenant_id = (SELECT core.current_tenant_id()));

-- Child table WITHOUT tenant_id - VULNERABLE!
CREATE TABLE tenant.order_item (
    id uuid PRIMARY KEY,
    order_id uuid NOT NULL REFERENCES tenant.orders(id) ON DELETE CASCADE,
    product_id uuid NOT NULL,
    quantity integer NOT NULL,
    price bigint NOT NULL
);

-- If someone queries order_item directly:
SELECT * FROM tenant.order_item WHERE product_id = $1;
-- Returns ALL order items across ALL tenants!
```

**Correct (child has its own tenant_id and RLS):**

```sql
-- Parent table with RLS (same as above)
CREATE TABLE tenant.orders (
    id uuid PRIMARY KEY,
    tenant_id uuid NOT NULL REFERENCES core.tenant(id),
    customer_id uuid NOT NULL,
    total bigint NOT NULL
);

ALTER TABLE tenant.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE tenant.orders FORCE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON tenant.orders
    FOR ALL
    USING (tenant_id = (SELECT core.current_tenant_id()))
    WITH CHECK (tenant_id = (SELECT core.current_tenant_id()));

-- Child table WITH tenant_id and RLS - SECURE
CREATE TABLE tenant.order_item (
    id uuid PRIMARY KEY,
    order_id uuid NOT NULL REFERENCES tenant.orders(id) ON DELETE CASCADE,
    tenant_id uuid NOT NULL REFERENCES core.tenant(id),  -- Defense-in-depth
    product_id uuid NOT NULL,
    quantity integer NOT NULL,
    price bigint NOT NULL
);

ALTER TABLE tenant.order_item ENABLE ROW LEVEL SECURITY;
ALTER TABLE tenant.order_item FORCE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON tenant.order_item
    FOR ALL
    USING (tenant_id = (SELECT core.current_tenant_id()))
    WITH CHECK (tenant_id = (SELECT core.current_tenant_id()));

-- Now direct queries are isolated:
SELECT * FROM tenant.order_item WHERE product_id = $1;
-- Returns only items for current tenant
```

**Consistency Check Constraint:**

```sql
-- Optional: Ensure child tenant_id matches parent tenant_id
ALTER TABLE tenant.order_item
ADD CONSTRAINT chk_order_item_tenant_matches_order
CHECK (
    NOT EXISTS (
        SELECT 1 FROM tenant.orders o
        WHERE o.id = order_id AND o.tenant_id != order_item.tenant_id
    )
);
```

**Gleam/Squirrel Pattern:**

```gleam
// Always include tenant_id in INSERT
pub fn create_order_item(
  db: Connection,
  tenant_id: String,  // Explicit parameter
  order_id: String,
  product_id: String,
  quantity: Int,
  price: Int,
) -> Result(OrderItem, Error) {
  sql.insert_order_item(db, [
    uuid_generate_v7(),
    order_id,
    tenant_id,  // Include in child row
    product_id,
    quantity,
    price,
  ])
}
```

**Why This Matters:**

- Direct queries on child tables bypass parent JOIN
- Foreign key constraints don't enforce RLS
- Cascade deletes work independently of RLS
- Defense-in-depth: multiple layers prevent single-point failures

**Rule:** ALL tenant-scoped tables (parent and child) should have their own `tenant_id` column and RLS policy. Don't rely solely on foreign key relationships for multi-tenant isolation.

**Source:** Kafka lessons.md (2026-02-10 PR #51)

Reference: [PostgreSQL RLS](https://www.postgresql.org/docs/current/ddl-rowsecurity.html)
