# HTTP Methods

## Goal

Understand supported HTTP methods in Next.js route handlers.

## Supported Methods

- `GET`
- `POST`
- `PUT`
- `PATCH`
- `DELETE`
- `HEAD`
- `OPTIONS`

## Examples

```typescript
// ✅ Correct - GET handler
// app/api/invoices/route.ts
export async function GET() {
  const invoices = await getInvoices()
  return Response.json({ data: invoices })
}
```

```typescript
// ✅ Correct - POST handler
// app/api/invoices/route.ts
export async function POST(request: Request) {
  const body = await request.json()
  const result = await createInvoice(body)
  return Response.json({ data: result }, { status: 201 })
}
```

```typescript
// ✅ Correct - multiple methods
// app/api/invoices/[id]/route.ts
export async function GET(
  request: Request,
  { params }: { params: { id: string } }
) {
  const invoice = await getInvoice(params.id)
  return Response.json({ data: invoice })
}

export async function PUT(
  request: Request,
  { params }: { params: { id: string } }
) {
  const body = await request.json()
  const result = await updateInvoice(params.id, body)
  return Response.json({ data: result })
}

export async function DELETE(
  request: Request,
  { params }: { params: { id: string } }
) {
  await deleteInvoice(params.id)
  return new Response(null, { status: 204 })
}
```

## Best Practices

- Use appropriate HTTP methods for each operation
- Follow REST conventions (GET for read, POST for create, etc.)
