# Code Patterns

## Using use <- with Result Functions

Gleam's use <- syntax simplifies nested case expressions when working with Result types. Instead of pattern matching on each result, use result.try to chain operations and early-return on errors.

```gleam
/// Nested case approach
fn process(id: Int) -> Result(Output, Nil) {
  case fetch_item(id) {
    Ok(item) -> {
      case transform(item) {
        Ok(result) -> Ok(build_output(result))
        Error(_) -> Error(Nil)
      }
    }
    Error(_) -> Error(Nil)
  }
}

/// Using use <- with result.try
fn process(id: Int) -> Result(Output, Nil) {
  use item <- result.try(
    fetch_item(id) |> result.replace_error(Nil)
  )
  use result <- result.try(
    transform(item) |> result.replace_error(Nil)
  )
  Ok(build_output(result))
}
```

Use result.replace_error(\*) when the original error type differs from what the calling function expects.

## Extracting Helper Functions for Readability

When a function contains deeply nested logic or handles multiple concerns, extract focused helper functions. This improves readability and makes each piece of logic easier to test and maintain.

```gleam
/// Deeply nested approach
fn process_orders(orders: List(Order)) -> List(Record) {
  list.map(orders, fn(order) {
    case fetch_data(order.id) {
      Ok(data) -> {
        let items = list.map(data.items, fn(item) {
          case fetch_detail(item.id) {
            Ok(d) -> #(item, d)
            Error(_) -> #(item, default_detail())
          }
        })
        build_success_record(data, items)
      }
      Error(e) -> build_failure_record(order.id, e)
    }
  })
}

/// Extracted helper functions
fn process_orders(orders: List(Order)) -> List(Record) {
  list.map(orders, process_single_order)
}

fn process_single_order(order: Order) -> Record {
  case fetch_data(order.id) {
    Ok(data) -> build_success_record(data, fetch_items_with_details(data.items))
    Error(e) -> build_failure_record(order.id, e)
  }
}

fn fetch_items_with_details(items: List(Item)) -> List(#(Item, Detail)) {
  list.map(items, fn(item) {
    let detail = result.unwrap(fetch_detail(item.id), default_detail())
    #(item, detail)
  })
}
```

Each function should have a single responsibility: one for orchestration, one for processing individual items, and one for fetching related data.

## Verification Checklist

1. `gleam check` - must pass with no errors
2. `gleam format` - ensure consistent style
3. Check for unused imports/arguments warnings
4. Verify all `Result` types are handled
