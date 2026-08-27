---
title: Grep for Index Names Before Creating
impact: MEDIUM
impactDescription: Migration failures from index name collisions
tags: indexes, migrations, naming-conventions, schema-design
---

## Grep for Index Names Before Creating

Index names are globally unique within a schema. Creating an index with the same name as an existing index fails the migration. Prefix-based naming without collision checking leads to duplicates across related tables.

**Incorrect (name collision across migrations):**

```sql
-- Earlier migration: consignment_return_item table
CREATE INDEX idx_return_item_variant ON tenant.consignment_return_item (variant_id);

-- Later migration: return_item table (different entity!)
CREATE INDEX idx_return_item_variant ON tenant.return_item (variant_id);
-- ERROR: relation "idx_return_item_variant" already exists
-- Migration fails!
```

**Correct (unique prefix per entity):**

```sql
-- Earlier migration: consignment_return_item table
CREATE INDEX idx_cri_variant ON tenant.consignment_return_item (variant_id);
-- Prefix: cri = Consignment Return Item

-- Later migration: return_item table
CREATE INDEX idx_rr_item_variant ON tenant.return_item (variant_id);
-- Prefix: rr = Return Request (different entity)
-- No collision - migration succeeds
```

**Naming Convention Pattern:**

```sql
-- Format: idx_{table_abbrev}_{column(s)}
-- Use table's enum prefix or abbreviation for uniqueness

-- Examples:
CREATE INDEX idx_ord_customer ON tenant.orders (customer_id);
CREATE INDEX idx_ord_status_created ON tenant.orders (status, created_at);
CREATE INDEX idx_oli_product ON tenant.order_item (product_id);
CREATE INDEX idx_prod_sku ON tenant.product (sku);
CREATE INDEX idx_prod_deleted ON tenant.product (deleted_at) WHERE deleted_at IS NULL;
```

**Prevention Rule:**

Before naming an index, grep existing migrations:

```bash
# Search for candidate index name across all migrations
grep -r "idx_return_item_variant" server/migrations/
grep -r "idx_oli_" server/migrations/  # Find all order_item indexes
```

**Comment Explaining Collision Avoidance:**

```sql
-- Use rr (Return Request) prefix instead of ri (Return Item)
-- to avoid collision with consignment_return_item indexes
CREATE INDEX idx_rr_item_variant ON tenant.return_item (variant_id);
```

**Cigogne Migration Pattern:**

```sql
-- migration:up
CREATE INDEX idx_rr_item_variant ON tenant.return_item (variant_id);
CREATE INDEX idx_rr_item_product ON tenant.return_item (product_id);

-- migration:down
DROP INDEX IF EXISTS tenant.idx_rr_item_variant;
DROP INDEX IF EXISTS tenant.idx_rr_item_product;
```

**Detection Query:**

```sql
-- Find duplicate index names (should return 0 rows)
SELECT indexname, COUNT(*)
FROM pg_indexes
WHERE schemaname = 'tenant'
GROUP BY indexname
HAVING COUNT(*) > 1;
```

**Rule:** Before creating an index, grep existing migrations for the candidate name. Use entity-specific prefixes (from enum prefixes or abbreviations) to prevent collisions across related tables.

**Source:** Kafka lessons.md (2026-02-10 PR #51)

Reference: [PostgreSQL Indexes](https://www.postgresql.org/docs/current/indexes.html)
