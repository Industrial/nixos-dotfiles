# Recommended Validation Helpers

## Goal

Provide common validation helpers for route handlers.

## Recommended Helpers

- `utils/validation/isRecord.ts` -> `value is Record<string, unknown>`
- `utils/validation/coerceFirstString.ts` -> `unknown -> string | null`
- `utils/validation/coerceNumber.ts` -> `unknown -> number | null`

## Examples

```typescript
// utils/validation/isRecord.ts
export const isRecord = (value: unknown): value is Record<string, unknown> => {
  return typeof value === "object" && value !== null && !Array.isArray(value)
}
```

```typescript
// utils/validation/coerceFirstString.ts
export const coerceFirstString = (value: unknown): string | null => {
  if (typeof value === "string") {
    return value
  }
  if (
    Array.isArray(value) &&
    value.length > 0 &&
    typeof value[0] === "string"
  ) {
    return value[0]
  }
  return null
}
```

```typescript
// utils/validation/coerceNumber.ts
export const coerceNumber = (value: unknown): number | null => {
  if (typeof value === "number" && !isNaN(value)) {
    return value
  }
  if (typeof value === "string") {
    const parsed = Number(value)
    return isNaN(parsed) ? null : parsed
  }
  return null
}
```

## Usage

```typescript
// app/api/invoices/route.ts
import { isRecord } from "utils/validation/isRecord"
import { coerceNumber } from "utils/validation/coerceNumber"

export async function POST(request: Request) {
  const body: unknown = await request.json()

  if (!isRecord(body)) {
    return Response.json(
      { error: { code: "VALIDATION_ERROR", message: "Invalid request body" } },
      { status: 400 }
    )
  }

  const amount = coerceNumber(body.amount)
  if (amount === null) {
    return Response.json(
      { error: { code: "VALIDATION_ERROR", message: "Invalid amount" } },
      { status: 400 }
    )
  }

  // ...
}
```

## Best Practices

- Use guard helpers for simple validation
- Use Zod schemas for complex validation
- Keep helpers focused and reusable
