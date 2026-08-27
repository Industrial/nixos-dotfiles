# Higher-Order Functions for DRY SQL

Extract generic helpers that accept SQL functions as parameters when multiple functions differ only in which SQL function they call. Gleam functions are first-class.

## The Problem

```gleam
// DUPLICATION: 4 functions with identical structure
pub fn get_agreement_status(id: String, db: Connection) -> Result(StatusRow, Error) {
  case sql.get_agreement_status(db, id) {
    Ok([row]) -> Ok(StatusRow(row.id, row.name))
    Ok([]) -> Error(NotFound("Agreement status not found"))
    Ok(_) -> Error(InternalErr("Multiple status rows"))
    Error(err) -> Error(db.map_query_error(err, "agreement status"))
  }
}

pub fn get_shipment_status(id: String, db: Connection) -> Result(StatusRow, Error) {
  case sql.get_shipment_status(db, id) {  // Only this line differs!
    Ok([row]) -> Ok(StatusRow(row.id, row.name))
    Ok([]) -> Error(NotFound("Shipment status not found"))
    Ok(_) -> Error(InternalErr("Multiple status rows"))
    Error(err) -> Error(db.map_query_error(err, "shipment status"))
  }
}

pub fn get_return_status(id: String, db: Connection) -> Result(StatusRow, Error) {
  case sql.get_return_status(db, id) {  // Only this line differs!
    // ... same pattern
  }
}

pub fn get_item_return_status(id: String, db: Connection) -> Result(StatusRow, Error) {
  case sql.get_item_return_status(db, id) {  // Only this line differs!
    // ... same pattern
  }
}
```

## Generic Helper Pattern

```gleam
// Extract higher-order helper
pub fn lookup_status(
  query_result: Result(List(StatusRow), pog.QueryError),
  entity_name: String,
) -> Result(StatusRow, Error) {
  case query_result {
    Ok([row]) -> Ok(row)
    Ok([]) -> Error(NotFound(entity_name <> " status not found"))
    Ok(_) -> Error(InternalErr("Multiple " <> entity_name <> " status rows"))
    Error(err) -> Error(db.map_query_error(err, entity_name <> " status"))
  }
}

// Now callsites are one-liners
pub fn get_agreement_status(id: String, db: Connection) -> Result(StatusRow, Error) {
  lookup_status(sql.get_agreement_status(db, id), "agreement")
}

pub fn get_shipment_status(id: String, db: Connection) -> Result(StatusRow, Error) {
  lookup_status(sql.get_shipment_status(db, id), "shipment")
}

pub fn get_return_status(id: String, db: Connection) -> Result(StatusRow, Error) {
  lookup_status(sql.get_return_status(db, id), "return")
}

pub fn get_item_return_status(id: String, db: Connection) -> Result(StatusRow, Error) {
  lookup_status(sql.get_item_return_status(db, id), "item return")
}
```

## Function Parameter Pattern

```gleam
// Helper accepts SQL function as parameter
pub fn set_optional_address(
  db: Connection,
  id: String,
  tenant_id: String,
  address_id: Option(String),
  setter_fn: fn(Connection, String, String, String) -> Result(Nil, Error),
) -> Result(Nil, Error) {
  case address_id {
    Some(addr_id) -> setter_fn(db, id, tenant_id, addr_id)
    None -> Ok(Nil)
  }
}

// Usage with different SQL functions
pub fn create_fulfillment_row(db: Connection, data: FulfillmentData) -> Result(Nil, Error) {
  // Set origin address if provided
  use _ <- result.try(set_optional_address(
    db,
    data.id,
    data.tenant_id,
    data.origin_address_id,
    sql.set_fulfillment_origin_address,  // SQL function passed as parameter
  ))

  // Set destination address if provided
  use _ <- result.try(set_optional_address(
    db,
    data.id,
    data.tenant_id,
    data.destination_address_id,
    sql.set_fulfillment_destination_address,  // Different SQL function
  ))

  Ok(Nil)
}
```

## When to Extract

Extract a higher-order helper when:

1. **2+ functions** have identical structure
2. **Only the called SQL function varies** between them
3. **Same error handling pattern** across all

Don't extract when:

- Functions have different error handling
- Different result transformations needed
- Only 1 occurrence (premature abstraction)

## Pattern Recognition

```gleam
// Look for this pattern (repeated structure, different function)
case sql.function_a(db, id) {  // ← Only difference
  Ok([item]) -> Ok(transform(item))
  Ok([]) -> Error(NotFound("entity"))
  Ok(_) -> Error(InternalErr("Multiple"))
  Error(err) -> Error(map_error(err))
}

case sql.function_b(db, id) {  // ← Only difference
  Ok([item]) -> Ok(transform(item))
  Ok([]) -> Error(NotFound("entity"))
  Ok(_) -> Error(InternalErr("Multiple"))
  Error(err) -> Error(map_error(err))
}

// Extract to:
fn lookup_one(result: Result(List(a), Error), entity: String) -> Result(a, Error)
```

## Benefits

- **DRY**: Single source of truth for error handling pattern
- **Maintainability**: Fix bugs in one place
- **Readability**: Callsites become one-liners
- **Type safety**: Gleam ensures function signatures match

**Source:** Kafka lessons.md (2026-02-09 W-008, 2026-02-10 PR #46)
