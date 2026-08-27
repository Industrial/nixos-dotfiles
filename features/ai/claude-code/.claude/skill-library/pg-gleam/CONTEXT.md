# pg-gleam — Postgres best practices for Gleam
> Last updated: 2026-04-25

Postgres performance optimization aligned with the Gleam backend stack
(Squirrel/Parrot + POG + Cigogne). Covers schema design, query
performance, connection management, security/RLS, locking, and
monitoring.

Inherits: `skills/CONTEXT.md`.

## Layout
```
pg-gleam/
├── SKILL.md
└── references/
    ├── schema-*.md          # Schema design (12 files)
    ├── query-*.md           # Query performance (8 files)
    ├── conn-*.md            # Connection management (5 files)
    ├── security-*.md        # Security & RLS (7 files)
    ├── lock-*.md            # Concurrency & locking (4 files)
    ├── data-*.md            # Data access patterns (5 files)
    ├── monitor-*.md         # Monitoring & diagnostics (4 files)
    ├── advanced-*.md        # Advanced features (5 files)
    ├── _template.md         # Template for new references
    ├── _sections.md         # Section structure guide
    └── _contributing.md     # Contributing guide for this skill
```

## Reference routing — by task

| Task                          | References to read                                                               |
|-------------------------------|----------------------------------------------------------------------------------|
| Designing a new table         | `schema-primary-keys.md` + `schema-data-types.md` + `schema-naming-conventions.md` |
| Adding Enum columns           | `schema-enums.md`                                                                |
| Adding Audit / Soft Deletes   | `schema-audit-fields.md` + `schema-soft-deletes.md`                              |
| Implementing RLS (Tenant Isolation)| `security-rls-basics.md` + `security-session-variables.md`                  |
| RLS on Child Tables           | `security-rls-child-tables.md` + `security-rls-performance.md`                   |
| Optimizing slow queries       | `query-missing-indexes.md` + `monitor-explain-analyze.md`                        |
| Creating indexes              | `schema-foreign-key-indexes.md` + `query-composite-indexes.md`                   |
| Writing batch inserts         | `data-batch-inserts.md`                                                          |
| Implementing pagination       | `data-pagination.md`                                                             |
| Handling concurrent updates   | `lock-short-transactions.md` + `lock-skip-locked.md`                             |
| Configuring POG connections   | `conn-pooling.md` + `conn-limits.md`                                             |

## Reference routing — by topic

| Topic                                    | Reference                                       |
|------------------------------------------|-------------------------------------------------|
| Postgres Data Types to Gleam mapping     | `schema-data-types.md`                          |
| UUIDv7 generation                        | `schema-primary-keys.md`                        |
| Row Level Security (RLS) performance     | `security-rls-performance.md`                   |
| Partial & Covering Indexes               | `query-partial-indexes.md` + `query-covering-indexes.md`|
| JSONB Indexing                           | `advanced-jsonb-indexing.md`                    |
| Full Text Search                         | `advanced-full-text-search.md`                  |
| Deadlock prevention                      | `lock-deadlock-prevention.md`                   |
| N+1 Query prevention                     | `data-n-plus-one.md`                            |
| Upserts (`ON CONFLICT`)                  | `data-upsert.md`                                |
| Connection Pooling & Idle timeouts       | `conn-pooling.md` + `conn-idle-timeout.md`      |
| Prepared Statements                      | `conn-prepared-statements.md`                   |

## Reference counts
| Category    | Prefix       | Files | Priority |
|-------------|--------------|-------|----------|
| Schema      | `schema-`    | 12    | HIGH     |
| Query       | `query-`     | 8     | CRITICAL |
| Connection  | `conn-`      | 5     | CRITICAL |
| Security    | `security-`  | 7     | CRITICAL |
| Locking     | `lock-`      | 4     | MEDIUM   |
| Data access | `data-`      | 5     | MEDIUM   |
| Monitoring  | `monitor-`   | 4     | LOW      |
| Advanced    | `advanced-`  | 5     | LOW      |

## Common pog/Postgres gotchas

### Transactions
- **No nested `pog.transaction`.** An inner `BEGIN` warns and an inner
  `COMMIT` commits the outer transaction. If middleware provides the
  transaction, handlers execute queries directly on the connection
- **Rollback-based test isolation:** never call `pog.transaction` inside
  a rollback test context — inner COMMIT kills the rollback

### SQL codegen (Parrot/Squirrel)
- **Batch operations (UNNEST queries) must be hand-written** — Parrot
  and Squirrel cannot generate them
- **Never edit generated `sql.gleam` files.** Fix the `.sql` source,
  regenerate, then update handlers to match new types

## Editing guidance
- New references follow `_template.md` structure
- Use the prefix convention (`schema-`, `query-`, etc.) for discoverability
- `_sections.md` defines the standard section order within each reference
