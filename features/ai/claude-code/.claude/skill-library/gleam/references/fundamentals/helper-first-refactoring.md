# Helper-First Refactoring Pattern

When refactoring to extract shared helpers, add the helpers FIRST with their final API, THEN migrate callsites incrementally. Prevents circular dependencies during refactoring.

## The Problem

```gleam
// Attempt 1: Change helper signature while migrating usages
// helper/http/uuid.gleam
pub fn parse_optional(opt: Option(String)) -> Result(Option(Uuid), String) {
  // Changed from entity-specific error type to generic String
}

// order/order.gleam - still using old signature
pub fn parse_optional_uuid(opt: Option(String)) -> Result(Option(Uuid), OrderError) {
  // Local version still exists, uses OrderError
}

// Attempt to migrate: circular dependency!
// Can't change helper signature because old usages expect old type
// Can't migrate usages because new helper doesn't exist yet
```

## Helper-First Workflow

### Phase 1: Add Helpers (Final API)

```gleam
// helper/http/uuid.gleam
// Add new helpers with FINAL signature
pub fn parse_optional(
  opt: Option(String),
  field_name: String,
) -> Result(Option(Uuid), error.Error) {
  case opt {
    None -> Ok(None)
    Some(s) -> {
      uuid.from_string(s)
      |> result.replace_error(error.ValidationErr("Invalid " <> field_name))
      |> result.map(Some)
    }
  }
}

pub fn parse_required(
  value: String,
  field_name: String,
) -> Result(Uuid, error.Error) {
  uuid.from_string(value)
  |> result.replace_error(error.ValidationErr("Invalid " <> field_name))
}

// Commit: "Phase 1: Add missing HTTP helpers"
// ✓ Compiles (new helpers don't break existing code)
// ✓ Tests can be added for new helpers
// ✓ Documentation updated
```

### Phase 2+: Migrate Callsites Incrementally

```gleam
// order/order.gleam - Phase 2
import helper/http/uuid as http_uuid

// REMOVE local duplicate
// pub fn parse_optional_uuid(...) { ... }

// Migrate to shared helper with error mapping
pub fn validate_supplier_id(opt: Option(String)) -> Result(Option(Uuid), OrderError) {
  http_uuid.parse_optional(opt, "supplier_id")
  |> result.map_error(fn(err) {
    case err {
      error.ValidationErr(msg) -> OrderError(InvalidUuid(msg))
      _ -> OrderError(InternalErr)
    }
  })
}

// Commit: "Phase 2: Migrate order module to shared helpers"
// ✓ Compiles (helper exists from Phase 1)
// ✓ Can pause/resume migration
```

```gleam
// line_item/line_item.gleam - Phase 3
import helper/http/uuid as http_uuid

// REMOVE local duplicate
// Migrate to shared helper (same pattern)
pub fn validate_product_id(opt: Option(String)) -> Result(Option(Uuid), LineItemError) {
  http_uuid.parse_optional(opt, "product_id")
  |> result.map_error(fn(err) {
    case err {
      error.ValidationErr(msg) -> LineItemError(InvalidUuid(msg))
      _ -> LineItemError(InternalErr)
    }
  })
}

// Commit: "Phase 3: Migrate line_item module to shared helpers"
```

## Benefits

### 1. Each commit compiles
- No broken intermediate states
- Can pause migration at any phase
- CI/CD stays green throughout

### 2. Reviewers understand changes
- Phase 1: Focus on helper API design
- Phase 2+: Focus on migration correctness
- Smaller, atomic commits

### 3. Parallel migration possible
- Different modules can be migrated by different PRs
- No conflicts if helpers are stable

### 4. No circular dependencies
- Helpers exist before usages
- Old code unaffected until migrated

## Anti-Pattern to Avoid

```gleam
// DON'T: Add helpers AND migrate usages in same commit
// helper/http/uuid.gleam - new helpers
pub fn parse_optional(...) { ... }

// order/order.gleam - migrate
// line_item/line_item.gleam - migrate
// fulfillment/fulfillment.gleam - migrate

// Commit: "Add UUID helpers and migrate all modules"
// ✗ Large changeset (hard to review)
// ✗ Mixes API design with migration mechanics
// ✗ Can't pause mid-migration
```

## Phase Structure

```
Phase 1: Add helpers to helper/http/
  ├─ Add parse_optional to uuid.gleam
  ├─ Add metadata.gleam with to_json
  ├─ Update docs (http-helpers.md, architecture.md)
  └─ Commit: "Phase 1: Add missing HTTP helpers"

Phase 2-5: Migrate callsites to use helpers
  ├─ Replace order.parse_optional_uuid with http_uuid.parse_optional
  ├─ Replace local option_string_to_json with metadata.to_json
  └─ Commit: "Phase 2: Migrate order module to shared helpers"

Phase 6: (Optional) Remove obsolete patterns
  ├─ Grep for remaining duplicates
  └─ Commit: "Phase 6: Remove obsolete UUID parsing helpers"
```

## Detection

```bash
# Find duplicate implementations before refactoring
rg "pub fn parse_optional_uuid" server/src/

# After Phase 1, verify helpers exist
ls helper/http/uuid.gleam
ls helper/http/metadata.gleam

# Track migration progress
rg "http_uuid.parse_optional" server/src/  # Count migrated usages
rg "parse_optional_uuid" server/src/        # Count remaining duplicates
```

**Source:** Kafka lessons.md (2026-02-09 Code Simplification Phase 1)
