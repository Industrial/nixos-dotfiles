# Protecting Server-Only Code

## Goal

Prevent server-only code from being imported into Client Components.

## Rule

Avoid importing server-only code (secrets, DB calls) into Client Components.

## Server-Only Code

- Database queries
- Environment variables with secrets
- File system access
- Server-side APIs

## Protection Strategies

- Keep server-only code in Server Components or route handlers
- Use `server-only` package (optional) to mark modules as server-only
- Use `client-only` package (optional) to mark modules as client-only

## Examples

```typescript
// ✅ Correct - server-only code in Server Component
// app/invoices/page.tsx
import { getInvoices } from "services/invoices/getInvoices"; // Server-only

export default async function InvoicesPage() {
  const invoices = await getInvoices(); // Server-side
  return <div>{/* ... */}</div>;
}
```

```typescript
// ❌ Incorrect - server-only code in Client Component
// components/invoices/InvoiceList.tsx
'use client'

import { getInvoices } from "services/invoices/getInvoices"; // Server-only!

export const InvoiceList = () => {
  // This will fail - can't use server-only code in client
  const invoices = await getInvoices();
  return <div>{/* ... */}</div>;
}
```

```typescript
// ✅ Correct - using server-only marker (optional)
// services/invoices/getInvoices.ts
import "server-only" // Marks this module as server-only

export const getInvoices = async () => {
  // Server-only code
}
```

## Best Practices

- Keep server-only code separate from client code
- Use Server Components for server-only operations
- Consider using `server-only` package for extra protection
