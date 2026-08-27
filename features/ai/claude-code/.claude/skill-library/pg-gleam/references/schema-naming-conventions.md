---
title: Follow Naming Conventions for Constraints and Schemas
impact: HIGH
impactDescription: Consistent naming aids migration tooling, debugging, and team communication
tags: naming, conventions, constraints, schemas
---

## Follow Naming Conventions for Constraints and Schemas

Use consistent prefixes for constraints and organize tables into purpose-specific schemas.

**Constraint naming prefixes:**

```sql
-- pk_  Primary key
-- fk_  Foreign key
-- uq_  Unique constraint
-- chk_ Check constraint
-- idx_ Index

create table tenant.order (
  id uuid default uuid_generate_v7() primary key
    constraint pk_order,
  tenant_id uuid not null
    constraint fk_order_tenant references core.tenant(id),
  customer_id uuid not null
    constraint fk_order_customer references tenant.customer(id),
  status order_status not null default 'os_pending'
    constraint chk_order_status check (status in ('os_pending', 'os_confirmed', 'os_shipped', 'os_cancelled')),
  order_number text not null
    constraint uq_order_number unique
);

create index idx_order_tenant_id on tenant.order (tenant_id) where deleted_at is null;
create index idx_order_customer_id on tenant.order (customer_id) where deleted_at is null;
```

**Multi-schema organization:**

```sql
-- core:       Tenant config, users, auth. Shared system-level tables.
-- tenant:     Business data scoped to a tenant. RLS-protected.
-- shared:     Reference data shared across tenants (countries, currencies, units).
-- extensions: Postgres extensions (pg_uuidv7, pgcrypto, etc.)

create schema if not exists core;
create schema if not exists tenant;
create schema if not exists shared;
create schema if not exists extensions;

-- Install extensions in dedicated schema
create extension if not exists pg_uuidv7 schema extensions;
set search_path to core, tenant, shared, extensions, public;
```

**Table naming:**

```sql
-- Singular, not plural
create table tenant.order (...);       -- not "orders"
create table tenant.customer (...);    -- not "customers"
create table core.tenant (...);        -- not "tenants"
create table shared.country (...);     -- not "countries"
```

**Column naming:**

```sql
-- snake_case, descriptive
-- FK columns match the referenced table: customer_id -> customer.id
-- Boolean columns: is_active, has_discount, can_edit
-- Timestamp columns: created_at, updated_at, deleted_at, shipped_at
```

Reference: [SQL Style Guide](https://www.sqlstyle.guide/)
