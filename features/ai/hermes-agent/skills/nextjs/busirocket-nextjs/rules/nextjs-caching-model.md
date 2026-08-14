# Caching Model

## Goal

Understand caching behavior for route handlers.

## Caching Rules

- Route handlers are **not cached by default**.
- Only `GET` can opt into caching.

## Examples

```typescript
// ✅ Correct - non-cached handler (default)
// app/api/invoices/route.ts
export async function POST(request: Request) {
  // Not cached by default
  const result = await createInvoice(await request.json())
  return Response.json({ data: result }, { status: 201 })
}
```

```typescript
// ✅ Correct - GET with caching
// app/api/invoices/route.ts
export const revalidate = 60 // Revalidate every 60 seconds

export async function GET() {
  const invoices = await getInvoices()
  return Response.json({ data: invoices })
}
```

```typescript
// ✅ Correct - GET with dynamic rendering
// app/api/invoices/route.ts
export const dynamic = "force-dynamic" // Disable caching

export async function GET() {
  const invoices = await getInvoices()
  return Response.json({ data: invoices })
}
```

## Best Practices

- Understand that handlers are not cached by default
- Use `revalidate` for GET handlers that can be cached
- Use `dynamic = "force-dynamic"` to disable caching when needed
