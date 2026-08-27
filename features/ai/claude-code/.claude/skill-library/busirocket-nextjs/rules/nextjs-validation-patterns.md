# Validation Patterns

## Goal

Establish consistent validation patterns for route handlers.

## Patterns

- Prefer `unknown` inputs at boundaries + explicit narrowing.
- Use tiny guard/coercion helpers instead of casting.

## Examples

```typescript
// ✅ Correct - unknown input with explicit narrowing
// app/api/invoices/route.ts
import { isRecord } from "utils/validation/isRecord"
import { InvoiceInputSchema } from "types/invoices/InvoiceInputSchema"

export async function POST(request: Request) {
  const body: unknown = await request.json()

  if (!isRecord(body)) {
    return Response.json(
      { error: { code: "VALIDATION_ERROR", message: "Invalid request body" } },
      { status: 400 }
    )
  }

  const result = InvoiceInputSchema.safeParse(body)
  // ...
}
```

```typescript
// ❌ Incorrect - type casting without validation
// app/api/invoices/route.ts
export async function POST(request: Request) {
  const body = (await request.json()) as InvoiceInput // Dangerous!
  const result = await createInvoice(body)
  return Response.json({ data: result }, { status: 201 })
}
```

```typescript
// ✅ Correct - guard helper instead of casting
// utils/validation/isNonEmptyString.ts
export const isNonEmptyString = (value: unknown): value is string => {
  return typeof value === "string" && value.trim().length > 0
}

// app/api/invoices/route.ts
import { isNonEmptyString } from "utils/validation/isNonEmptyString"

export async function POST(request: Request) {
  const body: unknown = await request.json()

  if (isRecord(body) && isNonEmptyString(body.name)) {
    // body.name is now typed as string
    // ...
  }
}
```

## Best Practices

- Use `unknown` for inputs at boundaries
- Use guard helpers for explicit narrowing
- Avoid type casting without validation
