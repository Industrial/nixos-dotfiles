# Stable API for Hooks

## Goal

Design hooks with stable, predictable APIs.

## Rules

- Return the minimal meaningful shape.
- Prefer stable references for handlers/derived values (`useCallback`,
  `useMemo`).

## Examples

```typescript
// ✅ Correct - minimal return shape
// hooks/invoices/useInvoice.ts
export const useInvoice = (id: string) => {
  const [invoice, setInvoice] = useState<Invoice | null>(null)
  const [isLoading, setIsLoading] = useState(true)

  return { invoice, isLoading }
}
```

```typescript
// ❌ Incorrect - returning too much
// hooks/invoices/useInvoice.ts
export const useInvoice = (id: string) => {
  const [invoice, setInvoice] = useState<Invoice | null>(null)
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<Error | null>(null)
  const internalState = {
    /* ... */
  }

  return { invoice, isLoading, error, internalState } // Too much!
}
```

```typescript
// ✅ Correct - stable handlers with useCallback
// hooks/invoices/useInvoice.ts
import { useCallback } from "react"

export const useInvoice = (id: string) => {
  const [invoice, setInvoice] = useState<Invoice | null>(null)

  const refreshInvoice = useCallback(async () => {
    const data = await getInvoice(id)
    setInvoice(data)
  }, [id])

  return { invoice, refreshInvoice }
}
```

## Props (when defining component props)

- Keep props minimal and descriptive; pass raw inputs, compute inside.
- Sort props alphabetically when feasible for consistency.

## Best Practices

- Return minimal, meaningful shapes
- Use `useCallback` for stable handlers
- Use `useMemo` for stable derived values
