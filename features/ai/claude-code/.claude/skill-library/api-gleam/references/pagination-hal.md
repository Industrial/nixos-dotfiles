---
title: Follow Canonical HAL Pagination Pattern Inside Result Blocks
impact: MEDIUM
impactDescription: Consistent pagination structure, correct error short-circuiting
tags: api, pagination, hal, result
---

## Follow Canonical HAL Pagination Pattern Inside Result Blocks

For paginated list endpoints, keep all pagination logic (param extraction, offset calculation, count query, PageInfo construction) inside the `result {}` block. This ensures pagination work doesn't execute when earlier steps fail.

**Incorrect (pagination outside result block):**

```gleam
pub fn list(req: Request, db: Connection, tenant_id: Uuid) -> Response {
  // Pagination extracted outside — runs even if tenant_id parsing fails
  let query_params = wisp.get_query(req)
  let page_params = params.get_page_params(query_params)
  let #(limit, offset) = hal.page_to_offset(page_params)

  use returned <- result.try(
    order_sql.list_orders(db, tenant_id, limit, offset)
  )
  let total = order_sql.count_orders(db, tenant_id)
  // PageInfo built in Ok arm — inconsistent with canonical pattern
  // ...
}
```

**Correct (everything inside result block):**

```gleam
pub fn list(req: Request, db: Connection, tenant_id: Uuid) -> Response {
  let result = {
    let query_params = wisp.get_query(req)
    let page_params = params.get_page_params(query_params)
    let #(limit, offset) = hal.page_to_offset(page_params)

    use total <- result.try(order_sql.count_orders(db, tenant_id))
    let page_info = hal.build_page_info(page_params, total)

    use returned <- result.try(
      order_sql.list_orders(db, tenant_id, limit, offset)
    )
    Ok(#(returned, page_info))
  }

  case result {
    Ok(#(orders, page_info)) ->
      order_view.list_json(orders, page_info) |> wisp.json_response(200)
    Error(err) -> error_response.handle(err)
  }
}
```

**Pattern summary:**

1. `get_page_params` + `page_to_offset` go **inside** the `result {}` block
2. Count query and `PageInfo` construction go **inside** the `result {}` block
3. Carry `page_info` through the tuple: `Ok(#(returned, page_info))`
4. The `Ok` arm receives pre-built `page_info`, not a raw `total` count
