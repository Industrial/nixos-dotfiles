# Component Testing

## Goal

Ensure components are tested consistently.

## Rule

- Every component should have corresponding tests in a `__tests__` folder (or
  mirror directory next to the component).
- Test both functionality and rendering.
- Use React Testing Library for component tests.

## Examples

```plaintext
components/
  invoices/
    InvoiceCard.tsx
    __tests__/
      InvoiceCard.test.tsx
```

```typescript
// ✅ Correct - test rendering and behavior
// components/invoices/__tests__/InvoiceCard.test.tsx
import { render, screen, userEvent } from "@testing-library/react"
import { InvoiceCard } from "../InvoiceCard"

describe("InvoiceCard", () => {
  it("renders invoice id and amount", () => {
    render(<InvoiceCard invoice={{ id: "1", amount: 100 }} />)
    expect(screen.getByText("1")).toBeInTheDocument()
    expect(screen.getByText("100")).toBeInTheDocument()
  })

  it("calls onSelect when clicked", async () => {
    const onSelect = jest.fn()
    render(<InvoiceCard invoice={{ id: "1", amount: 100 }} onSelect={onSelect} />)
    await userEvent.click(screen.getByRole("button"))
    expect(onSelect).toHaveBeenCalledWith("1")
  })
})
```

## Best Practices

- Co-locate tests under `__tests__` or mirror directory
- Test both rendering and user interactions
- Use React Testing Library (RTL) for component tests
