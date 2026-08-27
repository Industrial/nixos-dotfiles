# Server vs Client Components

## Goal

Understand when to use Server Components vs Client Components in Next.js App
Router.

## Server Components (Default)

- `app/**/page.tsx` and `app/**/layout.tsx` are **Server Components by
  default**.
- No `'use client'` directive needed.
- Can directly access server-only APIs (database, file system, etc.).

## Client Components

Use **Client Components** only when you need:

- State and event handlers (`onClick`, `onChange`)
- Effects (`useEffect`)
- Browser-only APIs (`window`, `localStorage`, etc.)

## Client Boundary

- `'use client'` creates a **boundary**: the file and all of its imports become
  part of the client bundle.
- Keep client islands small to reduce JS shipped to the browser.

## Examples

```typescript
// ✅ Correct - Server Component (default)
// app/invoices/page.tsx
export default async function InvoicesPage() {
  const invoices = await getInvoices(); // Server-side data fetching
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
  // No client features needed, but whole page is client
  return <div>{/* ... */}</div>;
}
```

## Best Practices

- Prefer Server Components by default
- Use Client Components only when necessary
- Keep client islands small and focused
