# HTTP Status Codes

## Goal

Use appropriate HTTP status codes for different scenarios.

## Status Codes

- `200`: OK
- `201`: Created
- `204`: No content (no JSON body)
- `400`: Validation / bad request
- `401`: Unauthorized
- `403`: Forbidden
- `404`: Not found
- `409`: Conflict
- `500`: Unexpected server error

## Examples

```typescript
// ✅ Correct - 200 OK
// app/api/invoices/route.ts
export async function GET() {
  const invoices = await getInvoices()
  return Response.json({ data: invoices }) // 200 default
}
```

```typescript
// ✅ Correct - 201 Created
// app/api/invoices/route.ts
export async function POST(request: Request) {
  const result = await createInvoice(await request.json())
  return Response.json({ data: result }, { status: 201 })
}
```

```typescript
// ✅ Correct - 204 No Content
// app/api/invoices/[id]/route.ts
export async function DELETE(
  request: Request,
  { params }: { params: { id: string } }
) {
  await deleteInvoice(params.id)
  return new Response(null, { status: 204 })
}
```

```typescript
// ✅ Correct - 400 Bad Request
// app/api/invoices/route.ts
export async function POST(request: Request) {
  const result = InvoiceInputSchema.safeParse(await request.json())
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
// ✅ Correct - 404 Not Found
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

- Use appropriate status codes for each scenario
- Follow REST conventions
- Return 204 for successful deletions
