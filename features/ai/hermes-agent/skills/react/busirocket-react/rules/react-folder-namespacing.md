# Folder Namespacing

## Goal

Organize complex components with children using folder namespacing.

## Rule

For complex components with children:

- `components/<area>/Parent/Parent.tsx`
- `components/<area>/Parent/Header.tsx`
- `components/<area>/Parent/Footer.tsx`

Avoid repeating the parent name in child filenames.

## Examples

```typescript
// ✅ Correct - folder namespacing
// components/invoices/InvoiceCard/InvoiceCard.tsx
export const InvoiceCard = () => {
  return (
    <div>
      <Header />
      <Footer />
    </div>
  );
};

// components/invoices/InvoiceCard/Header.tsx
export const Header = () => { /* ... */ }

// components/invoices/InvoiceCard/Footer.tsx
export const Footer = () => { /* ... */ }
```

```typescript
// ❌ Incorrect - repeating parent name
// components/invoices/InvoiceCard/InvoiceCardHeader.tsx
export const InvoiceCardHeader = () => {
  /* ... */
}
```

## Best Practices

- Use folder namespacing for complex components
- Avoid repeating parent name in child filenames
- Keep component hierarchy clear
