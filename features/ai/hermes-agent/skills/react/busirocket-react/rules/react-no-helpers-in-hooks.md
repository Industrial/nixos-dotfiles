# No Helpers Inside Hooks (STRICT)

## Goal

Keep hooks focused on state/effects, not helper logic.

## Rule

- Hooks contain only state/effects/memos and call helpers imported from
  `utils/`.
- Any helper must be its own file (one exported function per file).
- Do not keep large constant keyword lists or config maps inside hooks; import
  them from dedicated constants modules (e.g. `utils/<area>/constants/`).

## Examples

```typescript
// ❌ Incorrect - helper in hook
// hooks/invoices/useInvoice.ts
export const useInvoice = (id: string) => {
  const formatAmount = (amount: number): string => {
    return `$${amount.toFixed(2)}`
  }

  const [invoice, setInvoice] = useState<Invoice | null>(null)
  // ...
  return { invoice, formattedAmount: formatAmount(invoice?.amount ?? 0) }
}
```

```typescript
// ✅ Correct - helper extracted
// utils/invoices/formatAmount.ts
export const formatAmount = (amount: number): string => {
  return `$${amount.toFixed(2)}`
}

// hooks/invoices/useInvoice.ts
import { formatAmount } from "utils/invoices/formatAmount"

export const useInvoice = (id: string) => {
  const [invoice, setInvoice] = useState<Invoice | null>(null)
  // ...
  return {
    invoice,
    formattedAmount: invoice ? formatAmount(invoice.amount) : null,
  }
}
```

## Best Practices

- Extract all helpers to `utils/`
- Keep hooks focused on state/effects
- One helper function per file
