# API Response Rules

## Goal

Establish rules for consistent API responses.

## Rules

- Never return unvalidated request input.
- Do not throw for expected errors; return `{ error }` with an explicit status.
- Keep mapping minimal inside the route handler; do it in `services/` when
  possible.

## Examples

```typescript
// ❌ Incorrect - returning unvalidated input
// app/api/invoices/route.ts
export async function POST(request: Request) {
  const body = await request.json()
  return Response.json({ data: body }) // Dangerous!
}
```

```typescript
// ✅ Correct - validate before returning
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

  const serviceResult = await createInvoice(result.data)
  return Response.json({ data: serviceResult }, { status: 201 })
}
```

```typescript
// ❌ Incorrect - throwing for expected error
// app/api/invoices/[id]/route.ts
export async function GET(
  request: Request,
  { params }: { params: { id: string } }
) {
  const invoice = await getInvoice(params.id)
  if (!invoice) {
    throw new Error("Not found") // Should return error response
  }
  return Response.json({ data: invoice })
}
```

```typescript
// ✅ Correct - return error response
// app/api/invoices/[id]/route.ts
export async function GET(
  request: Request,
  { params }: { params: { id: string } }
) {
  const invoice = await getInvoice(params.id)
  if (!invoice) {
    return Response.json(
      { error: { code: "NOT_FOUND", message: "Invoice not found" } },
      { status: 404 }
    )
  }
  return Response.json({ data: invoice })
}
```

## Best Practices

- Always validate input before processing
- Return error responses instead of throwing
- Keep response mapping minimal
