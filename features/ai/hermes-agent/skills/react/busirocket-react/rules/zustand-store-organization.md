# Store Organization

## Goal

Organize Zustand stores for maintainability and performance.

## Store Organization Rules

- One store per domain: `uiStore`, `workspaceStore`, `statusLogStore`, etc.
- Keep stores focused; split when they grow too large
- Use selectors to minimize re-renders:
  `useStore((state) => state.specificValue)`
- Actions should be defined in the store, not in components

## Examples

```typescript
// ✅ Correct - one store per domain
// stores/uiStore.ts
import { create } from "zustand"

interface UiStore {
  isSettingsModalOpen: boolean
  openSettingsModal: () => void
  closeSettingsModal: () => void
}

export const useUiStore = create<UiStore>((set) => ({
  isSettingsModalOpen: false,
  openSettingsModal: () => set({ isSettingsModalOpen: true }),
  closeSettingsModal: () => set({ isSettingsModalOpen: false }),
}))
```

```typescript
// ✅ Correct - using selectors
// components/SettingsModal.tsx
import { useUiStore } from "stores/uiStore";

export const SettingsModal = () => {
  // Only re-renders when isSettingsModalOpen changes
  const isOpen = useUiStore((state) => state.isSettingsModalOpen);
  const closeModal = useUiStore((state) => state.closeSettingsModal);

  if (!isOpen) return null;
  return <div>{/* ... */}</div>;
};
```

```typescript
// ❌ Incorrect - not using selector
// components/SettingsModal.tsx
import { useUiStore } from "stores/uiStore";

export const SettingsModal = () => {
  // Re-renders on any store change
  const store = useUiStore();
  if (!store.isSettingsModalOpen) return null;
  return <div>{/* ... */}</div>;
};
```

```typescript
// ✅ Correct - actions in store
// stores/uiStore.ts
export const useUiStore = create<UiStore>((set) => ({
  isSettingsModalOpen: false,
  openSettingsModal: () => set({ isSettingsModalOpen: true }),
  closeSettingsModal: () => set({ isSettingsModalOpen: false }),
}))
```

```typescript
// ❌ Incorrect - actions in component
// components/SettingsButton.tsx
export const SettingsButton = () => {
  const store = useUiStore();

  const handleClick = () => {
    // Action should be in store, not component
    store.set({ isSettingsModalOpen: true });
  };

  return <button onClick={handleClick}>Settings</button>;
};
```

## Best Practices

- One store per domain
- Use selectors to minimize re-renders
- Define actions in the store
- Split stores when they grow too large
