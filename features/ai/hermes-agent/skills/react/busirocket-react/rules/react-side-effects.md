# Side Effects in Hooks

## Goal

Handle side effects correctly in hooks.

## Rules

- Fetch/subscribe in `useEffect` with cleanup.
- Avoid implicit dependencies; keep dependency arrays correct.

## Examples

```typescript
// ✅ Correct - useEffect with cleanup
// hooks/invoices/useInvoice.ts
import { useEffect, useState } from "react"

export const useInvoice = (id: string) => {
  const [invoice, setInvoice] = useState<Invoice | null>(null)

  useEffect(() => {
    let cancelled = false

    const fetchInvoice = async () => {
      const data = await getInvoice(id)
      if (!cancelled) {
        setInvoice(data)
      }
    }

    fetchInvoice()

    return () => {
      cancelled = true
    }
  }, [id])

  return invoice
}
```

```typescript
// ❌ Incorrect - missing dependencies
// hooks/invoices/useInvoice.ts
export const useInvoice = (id: string) => {
  const [invoice, setInvoice] = useState<Invoice | null>(null)

  useEffect(() => {
    getInvoice(id).then(setInvoice)
  }, []) // Missing 'id' dependency!
}
```

```typescript
// ✅ Correct - correct dependencies
// hooks/invoices/useInvoice.ts
export const useInvoice = (id: string) => {
  const [invoice, setInvoice] = useState<Invoice | null>(null)

  useEffect(() => {
    getInvoice(id).then(setInvoice)
  }, [id]) // Correct dependencies
}
```

## Best Practices

- Always include cleanup in useEffect
- Keep dependency arrays correct
- Avoid implicit dependencies
