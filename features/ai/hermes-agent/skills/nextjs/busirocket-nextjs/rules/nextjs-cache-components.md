# Cache Components Note

## Goal

Understand Cache Components behavior for route handlers.

## Cache Components Note

If Cache Components is enabled later:

- `GET` handlers follow the same model as UI routes.
- `use cache` **cannot** be used directly inside a Route Handler body; extract
  it to a helper function.

## Examples

```typescript
// ✅ Correct - extract cache to helper
// utils/cache/getCachedInvoices.ts
import { cache } from "react"
import { getInvoices } from "services/invoices/getInvoices"

export const getCachedInvoices = cache(async () => {
  return await getInvoices()
})

// app/api/invoices/route.ts
import { getCachedInvoices } from "utils/cache/getCachedInvoices"

export async function GET() {
  const invoices = await getCachedInvoices()
  return Response.json({ data: invoices })
}
```

```typescript
// ❌ Incorrect - use cache directly in handler
// app/api/invoices/route.ts
import { cache } from "react"

export async function GET() {
  // Cannot use cache() directly in route handler body
  const getCachedInvoices = cache(async () => {
    return await getInvoices()
  })
  const invoices = await getCachedInvoices()
  return Response.json({ data: invoices })
}
```

## Best Practices

- Extract `use cache` to helper functions when needed
- Keep route handlers clean and focused
