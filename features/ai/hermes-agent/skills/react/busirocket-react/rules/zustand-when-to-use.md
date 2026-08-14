# When to Use Zustand

## Goal

Understand when Zustand is appropriate for state management.

## When to Use Zustand

- Modal visibility states (settings, json, text, export menu)
- Global UI state (extraction progress, bulk processing)
- Shared data (selected invoice, toolbar config)
- Cross-component communication

## Examples

```typescript
// ✅ Correct - modal visibility state
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
// ✅ Correct - global UI state
// stores/uiStore.ts
interface UiStore {
  extractionProgress: number
  setExtractionProgress: (progress: number) => void
}

export const useUiStore = create<UiStore>((set) => ({
  extractionProgress: 0,
  setExtractionProgress: (progress) => set({ extractionProgress: progress }),
}))
```

## Best Practices

- Use Zustand for global UI state
- Use Zustand for cross-component communication
- Avoid using Zustand for server state (use React Query/SWR instead)
