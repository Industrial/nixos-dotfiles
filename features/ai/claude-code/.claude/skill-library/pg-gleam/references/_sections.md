# Section Definitions

This file defines the rule categories for Postgres best practices. Rules are automatically assigned to sections based on their filename prefix.

Take the examples below as pure demonstrative. Replace each section with the actual rule categories for Postgres best practices.

---

## 1. Query Performance (query)
**Impact:** CRITICAL
**Description:** Slow queries, missing indexes, inefficient query plans. The most common source of Postgres performance issues.

**New references:**
- `query-transaction-nesting.md` - Never nest pog.transaction calls (CRITICAL)
- `query-coalesce-empty-results.md` - COALESCE doesn't handle empty result sets (HIGH)

## 2. Connection Management (conn)
**Impact:** CRITICAL
**Description:** Connection pooling, limits, and serverless strategies. Critical for applications with high concurrency or serverless deployments.

**New references:**
- `conn-roles-vs-grants.md` - Roles are cluster-level, grants are per-database (MEDIUM)

## 3. Security & RLS (security)
**Impact:** CRITICAL
**Description:** Row-Level Security policies, privilege management, and authentication patterns.

**New references:**
- `security-session-variables.md` - Always use is_local=true for session variables (CRITICAL)
- `security-rls-migrations.md` - Disable RLS in data migrations (CRITICAL)
- `security-rls-with-check.md` - RLS policies must include WITH CHECK clause (HIGH)
- `security-rls-child-tables.md` - Child tables need their own tenant_id and RLS (MEDIUM)

## 4. Schema Design (schema)
**Impact:** HIGH
**Description:** Table design, index strategies, partitioning, and data type selection. Foundation for long-term performance.

**New references:**
- `schema-index-predicates.md` - Index predicates require IMMUTABLE functions (HIGH)
- `schema-index-naming.md` - Grep for index names before creating (MEDIUM)

## 5. Concurrency & Locking (lock)
**Impact:** MEDIUM-HIGH
**Description:** Transaction management, isolation levels, deadlock prevention, and lock contention patterns.

## 6. Data Access Patterns (data)
**Impact:** MEDIUM
**Description:** N+1 query elimination, batch operations, cursor-based pagination, and efficient data fetching.

**New references:**
- `data-count-list-sync.md` - Keep count and list query filters in sync (HIGH)

## 7. Monitoring & Diagnostics (monitor)
**Impact:** LOW-MEDIUM
**Description:** Using pg_stat_statements, EXPLAIN ANALYZE, metrics collection, and performance diagnostics.

**New references:**
- `monitor-schema-invariants.md` - Test schema invariants with catalog queries (MEDIUM-HIGH)

## 8. Advanced Features (advanced)
**Impact:** LOW
**Description:** Full-text search, JSONB optimization, PostGIS, extensions, and advanced Postgres features.

**New references:**
- `advanced-cigogne-patterns.md` - Cigogne single-transaction behavior (MEDIUM)
