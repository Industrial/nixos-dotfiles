# Client vs Server Components

## Goal

Understand when to use Client vs Server Components in Next.js App Router.

> **Note**: For detailed Next.js App Router patterns, see `busirocket-nextjs`.

## Rule

- Prefer Server Components by default.
- Add `'use client'` only when needed (state/effects/event handlers).

## Examples

```typescript
// ✅ Correct - Server Component (default)
// app/invoices/page.tsx
export default async function InvoicesPage() {
  const invoices = await getInvoices();
  return <div>{/* ... */}</div>;
}
```

```typescript
// ✅ Correct - Client Component when needed
// components/invoices/InvoiceModal.tsx
'use client'

import { useState } from "react";

export const InvoiceModal = () => {
  const [isOpen, setIsOpen] = useState(false);
  return <div>{/* ... */}</div>;
}
```

```typescript
// ❌ Incorrect - unnecessary client component
// app/invoices/page.tsx
'use client'

export default function InvoicesPage() {
  // No client features needed
  return <div>{/* ... */}</div>;
}
```

## Best Practices

- Default to Server Components
- Use Client Components only when necessary
- Keep client islands small
