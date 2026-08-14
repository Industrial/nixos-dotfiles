# Next.js Special File Exports

## Goal

Understand allowed exceptions for Next.js special files that require extra
exports.

## Exception Rule

This repository enforces "one export per file" for your own modules, **but
Next.js special files require extra exports**.

## Allowed Exceptions

### Layout and Page Files

- `app/**/layout.tsx`, `app/**/page.tsx`: `default export` + `metadata` /
  `generateMetadata` / `viewport` (and similar Next.js file-convention exports).

### Route Handlers

- `app/api/**/route.ts`: multiple HTTP method exports (GET/POST/...) + route
  config exports.

## Examples

```typescript
// ✅ Correct - Next.js page with metadata
// app/invoices/page.tsx
export const metadata = {
  title: "Invoices",
};

export default function InvoicesPage() {
  return <div>Invoices</div>;
}
```

```typescript
// ✅ Correct - Next.js layout with metadata
// app/invoices/layout.tsx
export const metadata = {
  title: "Invoices",
};

export default function InvoicesLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return <div>{children}</div>;
}
```

```typescript
// ✅ Correct - route handler with multiple methods
// app/api/invoices/route.ts
export async function GET() {
  return Response.json({ data: [] })
}

export async function POST(request: Request) {
  return Response.json({ data: {} })
}

export const dynamic = "force-dynamic"
```

```typescript
// ❌ Incorrect - multiple exports in regular component
// components/invoices/InvoiceCard.tsx
export const InvoiceCard = () => {
  /* ... */
}
export const InvoiceHeader = () => {
  /* ... */
} // Not allowed!
```

## Best Practices

- Only use multiple exports in Next.js special files
- Keep regular components/hooks/utils to one export per file
