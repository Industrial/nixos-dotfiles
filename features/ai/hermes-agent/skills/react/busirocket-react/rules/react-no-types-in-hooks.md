# No Types Inside Hooks (STRICT)

## Goal

Keep type definitions separate from hook implementations.

## Rule

- Do not define `interface`/`type` in hook files.
- Hook params/return types live in `types/<area>/...` (one type per file).

## Examples

```typescript
// ❌ Incorrect - type in hook
// hooks/invoices/useInvoice.ts
interface UseInvoiceReturn {
  invoice: Invoice | null
  isLoading: boolean
}

export const useInvoice = (id: string): UseInvoiceReturn => {
  // ...
}
```

```typescript
// ✅ Correct - type in types/
// types/invoices/UseInvoiceReturn.ts
export interface UseInvoiceReturn {
  invoice: Invoice | null
  isLoading: boolean
}

// hooks/invoices/useInvoice.ts
import type { UseInvoiceReturn } from "types/invoices/UseInvoiceReturn"

export const useInvoice = (id: string): UseInvoiceReturn => {
  // ...
}
```

## Best Practices

- Never define types in hook files
- Put types in `types/<area>/`
- One type per file
