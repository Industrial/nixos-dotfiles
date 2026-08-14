# Modal Pattern with Zustand

## Goal

Implement modals using Zustand for state management.

## Rule

Modals should consume store state directly:

- Modals should read their visibility state from stores, not receive as props.
- This avoids prop drilling and makes modal state globally accessible.

## Examples

```typescript
// ✅ Correct - modal reads from store
// components/JsonModal.tsx
import { useUiStore } from "stores/uiStore";

export function JsonModal({ resolvedTheme }: JsonModalProps) {
  const isOpen = useUiStore((state) => state.isJsonModalOpen);
  const closeModal = useUiStore((state) => state.closeJsonModal);

  if (!isOpen) return null;

  return (
    <div>
      {/* Modal content */}
      <button onClick={closeModal}>Close</button>
    </div>
  );
}
```

```typescript
// ❌ Incorrect - modal receives props
// components/JsonModal.tsx
interface JsonModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export function JsonModal({ isOpen, onClose }: JsonModalProps) {
  if (!isOpen) return null;
  return <div>{/* ... */}</div>;
}
```

```typescript
// ✅ Correct - store definition
// stores/uiStore.ts
import { create } from "zustand"

interface UiStore {
  isJsonModalOpen: boolean
  openJsonModal: () => void
  closeJsonModal: () => void
}

export const useUiStore = create<UiStore>((set) => ({
  isJsonModalOpen: false,
  openJsonModal: () => set({ isJsonModalOpen: true }),
  closeJsonModal: () => set({ isJsonModalOpen: false }),
}))
```

## Best Practices

- Modals read visibility from stores
- Avoid prop drilling for modal state
- Make modal state globally accessible
