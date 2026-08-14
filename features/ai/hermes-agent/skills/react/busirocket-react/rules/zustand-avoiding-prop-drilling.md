# Avoiding Prop Drilling

## Goal

Use Zustand stores instead of prop drilling for shared state.

## Pattern

Instead of passing callbacks through multiple components, use Zustand stores for
shared state.

## Examples

```typescript
// ❌ Incorrect - prop drilling
// components/Parent.tsx
export const Parent = ({ onOpenModal }: { onOpenModal: () => void }) => {
  return <Child onOpenModal={onOpenModal} />;
};

// components/Child.tsx
export const Child = ({ onOpenModal }: { onOpenModal: () => void }) => {
  return <Grandchild onOpenModal={onOpenModal} />;
};

// components/Grandchild.tsx
export const Grandchild = ({ onOpenModal }: { onOpenModal: () => void }) => {
  return <button onClick={onOpenModal}>Open</button>;
};
```

```typescript
// ✅ Correct - store access
// stores/uiStore.ts
import { create } from "zustand";

interface UiStore {
  openModal: () => void;
}

export const useUiStore = create<UiStore>((set) => ({
  openModal: () => set({ isModalOpen: true }),
}));

// components/Grandchild.tsx
import { useUiStore } from "stores/uiStore";

export const Grandchild = () => {
  const openModal = useUiStore((state) => state.openModal);
  return <button onClick={openModal}>Open</button>;
};
```

## Best Practices

- Use Zustand stores for shared state instead of prop drilling
- Access store actions directly in components that need them
- Avoid passing callbacks through 3+ component levels
