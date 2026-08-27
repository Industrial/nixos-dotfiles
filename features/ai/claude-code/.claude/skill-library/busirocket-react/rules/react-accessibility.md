# Accessibility Best Practices

## Goal

Ensure React components are accessible to all users.

## Accessibility Rules

- Use proper semantic HTML (`button`, `nav`, `main`, etc.).
- Add ARIA attributes where needed (`aria-label`, `aria-describedby`, roles).
- Support keyboard navigation for interactive elements.
- Ensure sufficient color contrast (e.g. WCAG 2.1).

## Examples

```typescript
// ✅ Correct - semantic HTML
// components/invoices/InvoiceCard.tsx
export const InvoiceCard = ({ invoice }: InvoiceCardProps) => {
  return (
    <article>
      <header>
        <h2>Invoice {invoice.id}</h2>
      </header>
      <main>
        <p>Amount: {invoice.amount}</p>
      </main>
    </article>
  );
};
```

```typescript
// ✅ Correct - ARIA attributes
// components/invoices/InvoiceModal.tsx
export const InvoiceModal = ({ isOpen, onClose }: InvoiceModalProps) => {
  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-labelledby="modal-title"
      aria-describedby="modal-description"
    >
      <h2 id="modal-title">Invoice Details</h2>
      <p id="modal-description">View invoice information</p>
      <button onClick={onClose} aria-label="Close modal">×</button>
    </div>
  );
};
```

```typescript
// ✅ Correct - keyboard navigation
// components/invoices/InvoiceCard.tsx
export const InvoiceCard = ({ invoice, onSelect }: InvoiceCardProps) => {
  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === "Enter" || e.key === " ") {
      onSelect(invoice.id);
    }
  };

  return (
    <div
      role="button"
      tabIndex={0}
      onClick={() => onSelect(invoice.id)}
      onKeyDown={handleKeyDown}
    >
      {invoice.id}
    </div>
  );
};
```

## Best Practices

- Use semantic HTML elements
- Add ARIA attributes when needed
- Support keyboard navigation
- Ensure color contrast meets WCAG standards
