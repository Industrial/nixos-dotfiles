# Validation Rules

## Goal

Establish rules for validation in route handlers.

## Rules

- No inline types or helpers inside route handlers.
- If validation logic grows, split into dedicated helpers (one function per
  file).

## Examples

```typescript
// ❌ Incorrect - inline type in route handler
// app/api/invoices/route.ts
export async function POST(request: Request) {
  interface InvoiceInput {
    name: string
    amount: number
  }

  const body = (await request.json()) as InvoiceInput
  // ...
}
```

```typescript
// ✅ Correct - type in types/
// types/invoices/InvoiceInput.ts
export interface InvoiceInput {
  name: string
  amount: number
}

// app/api/invoices/route.ts
import type { InvoiceInput } from "types/invoices/InvoiceInput"
```

```typescript
// ❌ Incorrect - inline helper in route handler
// app/api/invoices/route.ts
export async function POST(request: Request) {
  const validateInvoice = (body: unknown): body is InvoiceInput => {
    // Validation logic
  }

  const body = await request.json()
  if (!validateInvoice(body)) {
    // ...
  }
  // ...
}
```

```typescript
// ✅ Correct - helper in utils/
// utils/validation/validateInvoiceInput.ts
import type { InvoiceInput } from "types/invoices/InvoiceInput"

export const validateInvoiceInput = (value: unknown): value is InvoiceInput => {
  // Validation logic
}

// app/api/invoices/route.ts
import { validateInvoiceInput } from "utils/validation/validateInvoiceInput"
```

## Best Practices

- Extract types to `types/`
- Extract validation helpers to `utils/validation/`
- Keep route handlers focused on HTTP concerns
