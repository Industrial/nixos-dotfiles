# One Hook Per File (STRICT)

## Goal

Enforce strict one-hook-per-file discipline for maintainability.

## Rule

- Exactly one exported hook per file: `hooks/<area>/useXxx.ts`.
- No extra exports.

## Examples

```typescript
// ✅ Correct - one hook per file
// hooks/invoices/useInvoice.ts
export const useInvoice = (id: string) => {
  const [invoice, setInvoice] = useState<Invoice | null>(null)
  // ...
  return invoice
}
```

```typescript
// ❌ Incorrect - multiple hooks
// hooks/invoices/useInvoice.ts
export const useInvoice = () => {
  /* ... */
}
export const useInvoices = () => {
  /* ... */
} // Not allowed!
```

```typescript
// ❌ Incorrect - extra exports
// hooks/invoices/useInvoice.ts
export const useInvoice = () => {
  /* ... */
}
export const INVOICE_DEFAULT = {} // Not allowed!
```

## Complexity

- Keep hook cognitive complexity ≤ 15; extract helpers to `utils/` or split into
  smaller hooks when needed.

## Best Practices

- Strictly enforce one hook per file
- No extra exports in hook files
- Keep hooks focused and single-purpose
