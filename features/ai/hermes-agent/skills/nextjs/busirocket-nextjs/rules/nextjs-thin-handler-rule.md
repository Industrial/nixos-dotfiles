# Thin Handler Rule (STRICT)

## Goal

Keep route handlers thin and focused on HTTP concerns.

## Thin Handler Rule (STRICT)

Route handlers must be thin:

- Parse/validate request input
- Call a `services/<area>/...` function
- Return an explicit response

No business logic, no DB/network access directly in the handler.

## Examples

```typescript
// ✅ Correct - thin route handler
// app/api/invoices/route.ts
import { createInvoice } from "services/invoices/createInvoice"
import { InvoiceInputSchema } from "types/invoices/InvoiceInputSchema"

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

  if (!serviceResult.ok) {
    return Response.json({ error: serviceResult.error }, { status: 500 })
  }

  return Response.json({ data: serviceResult.value }, { status: 201 })
}
```

```typescript
// ❌ Incorrect - fat route handler with business logic
// app/api/invoices/route.ts
export async function POST(request: Request) {
  const body = await request.json()

  // Business logic should be in services/
  const invoice = {
    id: generateId(),
    amount: calculateTax(body.amount),
    createdAt: new Date(),
  }

  // DB access should be in services/
  await db.invoices.insert(invoice)

  return Response.json({ data: invoice }, { status: 201 })
}
```

## Best Practices

- Keep handlers thin: validate, call service, return response
- Move all business logic to services
- Never access DB/network directly in handlers
