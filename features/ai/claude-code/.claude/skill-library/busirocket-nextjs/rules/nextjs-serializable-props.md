# Serializable Props

## Goal

Ensure props passed from Server to Client Components are serializable.

## Rule

Props passed from Server -> Client must be **serializable**.

## Serializable Types

- Primitives: `string`, `number`, `boolean`, `null`, `undefined`
- Arrays of serializable values
- Plain objects with serializable values
- Dates (serialized as strings)

## Non-Serializable Types

- Functions
- Classes
- Symbols
- Promises
- React components
- Server-only APIs (database connections, etc.)

## Examples

```typescript
// ✅ Correct - serializable props
// app/invoices/page.tsx (Server Component)
import { InvoiceList } from "components/invoices/InvoiceList";

export default async function InvoicesPage() {
  const invoices = await getInvoices();
  return <InvoiceList invoices={invoices} />; // Plain objects
}
```

```typescript
// ✅ Correct - serializable props
// components/invoices/InvoiceList.tsx (Client Component)
'use client'

interface InvoiceListProps {
  invoices: Array<{
    id: string;
    amount: number;
    createdAt: string; // Date serialized as string
  }>;
}

export const InvoiceList = ({ invoices }: InvoiceListProps) => {
  return <div>{/* ... */}</div>;
}
```

```typescript
// ❌ Incorrect - non-serializable props
// app/invoices/page.tsx (Server Component)
import { InvoiceList } from "components/invoices/InvoiceList";

export default async function InvoicesPage() {
  const handleClick = () => {}; // Function not serializable
  return <InvoiceList onClick={handleClick} />;
}
```

```typescript
// ✅ Correct - pass data, not functions
// app/invoices/page.tsx (Server Component)
import { InvoiceList } from "components/invoices/InvoiceList";

export default async function InvoicesPage() {
  const invoices = await getInvoices();
  return <InvoiceList invoices={invoices} />;
}

// components/invoices/InvoiceList.tsx (Client Component)
'use client'

export const InvoiceList = ({ invoices }: InvoiceListProps) => {
  const handleClick = () => {}; // Function defined in client component
  return <div onClick={handleClick}>{/* ... */}</div>;
}
```

## Best Practices

- Only pass serializable data from Server to Client
- Define event handlers in Client Components
- Use Server Components for data fetching
