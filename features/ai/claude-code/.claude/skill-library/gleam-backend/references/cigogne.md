# Cigogne — Database Migrations for Gleam

Cigogne is a PostgreSQL migration manager for Gleam projects. It tracks applied migrations in a `schema_migrations` table and supports forward (`all`) and backward (`down`) operations.

## CLI Commands

All commands require `DATABASE_URL` as an environment variable:

```bash
# Apply all pending migrations
DATABASE_URL="postgres://user:pass@host:port/dbname" gleam run -m cigogne -- all

# Rollback the last applied migration
DATABASE_URL="postgres://user:pass@host:port/dbname" gleam run -m cigogne -- down

# Create a new migration file with a timestamp prefix
DATABASE_URL="postgres://user:pass@host:port/dbname" gleam run -m cigogne -- new --name "description"
```

The `new` command generates a file like `20260207030252-description.sql` in the configured migration folder.

## Configuration (`cigogne.toml`)

Place `cigogne.toml` in your project's `priv/` directory (or project root):

```toml
[database]
# Uses DATABASE_URL environment variable automatically

[migration-table]
schema = "public"           # Schema for the tracking table
table = "schema_migrations" # Table that records applied migrations

[migrations]
migration_folder = "migration"  # Relative to priv/

[migrations.dependencies]
# Add migration dependencies here if needed
```

## Migration File Format

Each `.sql` file uses three sentinel markers:

```sql
--- migration:up
-- Forward SQL statements here
CREATE TABLE tenant.example (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
    name TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

--- migration:down
-- Rollback SQL statements here (reverse of up)
DROP TABLE IF EXISTS tenant.example;

--- migration:end
```

**Rules:**
- `--- migration:up` — everything after this line runs on `all`
- `--- migration:down` — everything after this line runs on `down`
- `--- migration:end` — marks end of file (required)
- Each section can contain multiple SQL statements separated by `;`

## Naming Convention

Files follow `YYYYMMDDHHMMSS-kebab-description.sql`:

```
20260206232134-extensions-and-schemas.sql
20260206232155-core-identity.sql
20260206232207-tenant-catalog.sql
20260207030415-seed-shared-events.sql
```

Timestamps ensure deterministic ordering. Use descriptive kebab-case names that indicate what the migration does.

## Best Practices

### Always write both up and down

Every migration must be reversible. The `down` section should undo exactly what `up` does:

```sql
--- migration:up
ALTER TABLE tenant.product ADD COLUMN weight_grams INTEGER;

--- migration:down
ALTER TABLE tenant.product DROP COLUMN IF EXISTS weight_grams;

--- migration:end
```

### Use schema prefixes

This project uses three PostgreSQL schemas — always qualify table names:

```sql
CREATE TABLE core.user (...);       -- Identity, auth, infrastructure
CREATE TABLE tenant.product (...);  -- Multi-tenant business data
CREATE TABLE shared.book (...);     -- Shared bibliographic data
```

### Separate DDL from seed data

Use separate migration files for schema changes vs. data seeding:

```
20260207030252-shared-event-tables.sql      -- DDL: CREATE TABLE, indexes, RLS
20260207030415-seed-shared-events.sql       -- Data: INSERT INTO shared.event ...
```

This keeps rollbacks clean — dropping seed data doesn't require dropping tables.

### Row-Level Security setup pattern

For tenant-isolated tables, enable RLS in the same migration:

```sql
--- migration:up
CREATE TABLE tenant.example (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
    tenant_id UUID NOT NULL REFERENCES core.tenant(id),
    name TEXT NOT NULL
);

ALTER TABLE tenant.example ENABLE ROW LEVEL SECURITY;
ALTER TABLE tenant.example FORCE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON tenant.example
    USING (tenant_id = core.current_tenant_id());
```

### Audit trigger pattern

Attach standard audit triggers for business tables:

```sql
CREATE TRIGGER set_audit_insert
    BEFORE INSERT ON tenant.example
    FOR EACH ROW EXECUTE FUNCTION core.set_audit_fields_insert();

CREATE TRIGGER set_audit_update
    BEFORE UPDATE ON tenant.example
    FOR EACH ROW EXECUTE FUNCTION core.set_audit_fields_update();
```

### Index conventions

- **B-tree** (default) for equality/range lookups on foreign keys and status columns
- **BRIN** for time-series columns (`created_at`) on append-only tables
- **GIN** with `jsonb_path_ops` for JSONB metadata columns
- **Partial indexes** for filtered queries (e.g., `WHERE deleted_at IS NULL`)

```sql
CREATE INDEX idx_example_tenant ON tenant.example(tenant_id);
CREATE INDEX idx_example_created_at ON tenant.example USING BRIN(created_at);
CREATE INDEX idx_example_active ON tenant.example(id) WHERE deleted_at IS NULL;
```

## Workflow

1. Create migration: `gleam run -m cigogne -- new --name "add-product-weight"`
2. Edit the generated file with `up` and `down` SQL
3. Apply: `gleam run -m cigogne -- all`
4. If needed, write SQL query files in `domain/sql/*.sql`
5. Regenerate Gleam types: `gleam run -m squirrel`
6. Test rollback works: `gleam run -m cigogne -- down` then `gleam run -m cigogne -- all`
