# Performance Optimization

## Goal

Optimize React component performance.

## Performance Patterns

- Memoize expensive computations with `useMemo`.
- Use `useCallback` for stable handlers passed to children or effect deps.
- Consider `React.memo` for purely presentational components to avoid
  unnecessary re-renders.

## Examples

```typescript
// ✅ Correct - useMemo for expensive computation
// components/invoices/InvoiceList.tsx
import { useMemo } from "react";

export const InvoiceList = ({ invoices }: InvoiceListProps) => {
  const totalAmount = useMemo(() => {
    return invoices.reduce((sum, invoice) => sum + invoice.amount, 0);
  }, [invoices]);

  return <div>Total: {totalAmount}</div>;
};
```

```typescript
// ✅ Correct - useCallback for stable handler
// components/invoices/InvoiceCard.tsx
import { useCallback } from "react";

export const InvoiceCard = ({ invoice, onSelect }: InvoiceCardProps) => {
  const handleClick = useCallback(() => {
    onSelect(invoice.id);
  }, [invoice.id, onSelect]);

  return <div onClick={handleClick}>{/* ... */}</div>;
};
```

```typescript
// ✅ Correct - React.memo for presentational component
// components/invoices/InvoiceCard.tsx
import { memo } from "react";

export const InvoiceCard = memo(({ invoice }: InvoiceCardProps) => {
  return <div>{invoice.id}</div>;
});
```

## Best Practices

- Use `useMemo` for expensive computations
- Use `useCallback` for stable handlers
- Use `React.memo` for presentational components
