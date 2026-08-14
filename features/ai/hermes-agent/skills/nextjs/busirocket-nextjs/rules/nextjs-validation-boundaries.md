# Validation Boundaries

## Goal

Understand where validation code belongs in route handlers.

## Where Validation Lives

- **Route handlers**: validate request shape at the boundary.
- **Services**: validate invariants when enforcing domain policies.
- **Utils**: keep small coercion/guard helpers under `utils/validation/`.

## Examples

```typescript
// ✅ Correct - validation in route handler
// app/api/invoices/route.ts
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
  return Response.json({ data: serviceResult }, { status: 201 })
}
```

```typescript
// ✅ Correct - guard helper in utils/
// utils/validation/isNonEmptyString.ts
export const isNonEmptyString = (value: unknown): value is string => {
  return typeof value === "string" && value.trim().length > 0
}

// app/api/invoices/route.ts
import { isNonEmptyString } from "utils/validation/isNonEmptyString"

export async function POST(request: Request) {
  const body = await request.json()
  if (!isNonEmptyString(body.name)) {
    return Response.json(
      { error: { code: "VALIDATION_ERROR", message: "Name is required" } },
      { status: 400 }
    )
  }
  // ...
}
```

## Best Practices

- Validate request shape at route handler boundary
- Use guard helpers from `utils/validation/` for simple checks
- Use Zod schemas for complex validation
