# React skills for Cursor

Curated React agent skills under `.cursor/skills/react/`. **9 skills** covering performance, composition, UI/accessibility, data fetching, and general React/TS patterns.

## Quick pick

| Task | Skill |
|------|-------|
| Performance review / bundle / waterfalls | `react-best-practices` |
| Compound components, avoid boolean props | `composition-patterns` |
| Page / route view transitions | `react-view-transitions` |
| Accessibility & UI audit (100+ rules) | `web-design-guidelines` |
| Frontend architecture & patterns | `frontend-engineering` |
| TanStack Query / server state | `react-query` |
| Component & hook conventions | `mindrally-react` |
| UI/UX design patterns | `ui-design` |
| Project React standards (BusiRocket) | `busirocket-react` |

## Catalog

### Vercel official — [vercel-labs/agent-skills](https://github.com/vercel-labs/agent-skills) (MIT)

| Skill | Focus |
|-------|--------|
| `react-best-practices` | 40+ perf rules: waterfalls, bundle size, RSC, re-renders |
| `composition-patterns` | Compound components, state lifting, flexible APIs |
| `react-view-transitions` | `<ViewTransition>`, shared elements, Next.js `transitionTypes` |
| `web-design-guidelines` | a11y, forms, animation, perf, i18n for React UIs |

### Community

| Skill | Source | License |
|-------|--------|---------|
| `frontend-engineering` | [d-padmanabhan/agent-engineering-handbook](https://github.com/d-padmanabhan/agent-engineering-handbook) | See upstream |
| `mindrally-react` | [Mindrally/skills](https://github.com/Mindrally/skills) | See upstream |
| `react-query` | [Mindrally/skills](https://github.com/Mindrally/skills) | See upstream |
| `ui-design` | [Mindrally/skills](https://github.com/Mindrally/skills) | See upstream |
| `busirocket-react` | [BusiRocket/agents-skills](https://github.com/BusiRocket/agents-skills) | See upstream |

## Related skills in this repo

- `.cursor/skills/effect.ts-react/` — Effect.ts + Next.js App Router patterns for this monorepo
- `.cursor/skills/nextjs/` — Next.js-specific skills (App Router, RSC, caching)

## Updating

```bash
TMP=$(mktemp -d)
git clone --depth 1 https://github.com/vercel-labs/agent-skills.git "$TMP/as"
for s in react-best-practices composition-patterns react-view-transitions web-design-guidelines; do
  cp -a "$TMP/as/skills/$s" ".cursor/skills/react/$s"
done
```
