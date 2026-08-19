# One Component Per File (STRICT)

## Goal

Enforce strict one-component-per-file discipline for maintainability.

## Rule

- Exactly one exported component per `.tsx` file.
- No helper functions inside component files; extract to `utils/`.
- No inline types; import from `types/`.

## Examples

```typescript
// ✅ Correct - one component per file
// components/invoices/InvoiceCard.tsx
import type { Invoice } from "types/invoices/Invoice";

export const InvoiceCard = ({ invoice }: { invoice: Invoice }) => {
  return <div>{invoice.id}</div>;
};
```

```typescript
// ❌ Incorrect - multiple components
// components/invoices/InvoiceCard.tsx
export const InvoiceCard = () => {
  /* ... */
}
export const InvoiceHeader = () => {
  /* ... */
} // Not allowed!
```

```typescript
// ❌ Incorrect - helper in component
// components/invoices/InvoiceCard.tsx
export const InvoiceCard = ({ invoice }: InvoiceCardProps) => {
  const formatAmount = (amount: number): string => {
    return `$${amount.toFixed(2)}`;
  };
  return <div>{formatAmount(invoice.amount)}</div>;
};
```

```typescript
// ✅ Correct - helper extracted
// utils/invoices/formatAmount.ts
export const formatAmount = (amount: number): string => {
  return `$${amount.toFixed(2)}`
}

// components/invoices/InvoiceCard.tsx
import { formatAmount } from "utils/invoices/formatAmount"
```

## Best Practices

- Strictly enforce one component per file
- Extract all helpers to `utils/`
- Import types from `types/`
