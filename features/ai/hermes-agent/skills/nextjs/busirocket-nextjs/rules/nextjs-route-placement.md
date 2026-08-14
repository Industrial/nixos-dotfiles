# Route Handler Placement

## Goal

Understand where route handlers live and conflicts with pages.

## Placement

- Route handlers live in `app/**/route.ts`.

## Conflict Rule

You **cannot** have `route.ts` and `page.tsx` in the same route segment.

## Examples

```typescript
// ✅ Correct - route handler
// app/api/invoices/route.ts
export async function GET() {
  return Response.json({ data: [] })
}
```

```typescript
// ✅ Correct - page in different segment
// app/invoices/page.tsx
export default function InvoicesPage() {
  return <div>Invoices</div>;
}
```

```typescript
// ❌ Incorrect - conflict in same segment
// app/invoices/route.ts
export async function GET() {
  return Response.json({ data: [] });
}

// app/invoices/page.tsx
export default function InvoicesPage() {
  return <div>Invoices</div>;
}
// Error: Cannot have both route.ts and page.tsx in same segment
```

## Best Practices

- Use `app/api/**/route.ts` for API endpoints
- Use `app/**/page.tsx` for UI pages
- Never mix route handlers and pages in the same segment
