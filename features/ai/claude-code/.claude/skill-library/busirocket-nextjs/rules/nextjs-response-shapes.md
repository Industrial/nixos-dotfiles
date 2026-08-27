# Standard JSON Response Shapes

## Goal

Keep API responses predictable, typed, and easy to consume.

## Standard JSON Shapes

Prefer one of these:

- **Success**: `Response.json({ data })`
- **Error**: `Response.json({ error: { code, message } }, { status })`

## Examples

```typescript
// ✅ Correct - success response
// app/api/invoices/route.ts
export async function GET() {
  const invoices = await getInvoices()
  return Response.json({ data: invoices })
}
```

```typescript
// ✅ Correct - error response
// app/api/invoices/route.ts
export async function POST(request: Request) {
  const body = await request.json()
  const result = InvoiceInputSchema.safeParse(body)

  if (!result.success) {
    return Response.json(
      { error: { code: "VALIDATION_ERROR", message: result.error.message } },
      { status: 400 }
    )
  }

  // ...
}
```

```typescript
// ❌ Incorrect - inconsistent response shape
// app/api/invoices/route.ts
export async function GET() {
  const invoices = await getInvoices()
  return Response.json(invoices) // Should wrap in { data }
}
```

## Best Practices

- Always use `{ data }` for success responses
- Always use `{ error: { code, message } }` for errors
- Keep response shapes consistent across all endpoints
