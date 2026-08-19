# Next.js skills for Cursor

Curated Next.js agent skills under `.cursor/skills/nextjs/`. **14 skills** covering App Router conventions, upgrades, caching, auth, UI libraries, AI SDK, and Supabase integration.

## Quick pick

| Task | Skill |
|------|-------|
| App Router / RSC / metadata / routing | `next-best-practices` |
| Upgrade between Next.js versions | `next-upgrade` |
| Cache Components, `'use cache'`, PPR | `next-cache-components` |
| Next.js 16 breaking changes & Turbopack | `nextjs16-skills` |
| shadcn/ui in App Router | `shadcn-skills` |
| Clerk auth (App Router, proxy.ts) | `clerk-nextjs-skills` |
| Auth.js v5 | `authjs-skills` |
| Supabase + Next.js | `supabase-nextjs` |
| Vercel AI SDK 6 + agents | `ai-sdk-6-skills`, `ai-agents-ui-skills` |
| MCP servers in Next.js | `mcp-server-skills` |
| TypeScript Next.js conventions | `mindrally-nextjs-react-typescript`, `mindrally-optimized-nextjs-typescript` |
| Project Next.js standards | `busirocket-nextjs` |

## Catalog

### Vercel official — [vercel-labs/next-skills](https://github.com/vercel-labs/next-skills) (MIT)

| Skill | Focus |
|-------|--------|
| `next-best-practices` | File conventions, RSC boundaries, data patterns, async APIs, metadata, errors, bundling |
| `next-upgrade` | Version migration guides |
| `next-cache-components` | Next.js 16 Cache Components, `'use cache'`, `cacheLife`, `cacheTag` |

### Next.js 16 ecosystem — [gocallum/nextjs16-agent-skills](https://github.com/gocallum/nextjs16-agent-skills) (MIT)

| Skill | Focus |
|-------|--------|
| `nextjs16-skills` | Next.js 16 facts, async request APIs, Turbopack, upgrade path |
| `shadcn-skills` | shadcn/ui install, components, theming, MCP |
| `clerk-nextjs-skills` | Clerk + App Router, `proxy.ts`, OAuth |
| `authjs-skills` | Auth.js v5, providers, env setup |
| `mcp-server-skills` | MCP handlers in Next.js with shared Zod schemas |
| `ai-agents-ui-skills` | ToolLoopAgent, AI SDK UI, tool calling |
| `ai-sdk-6-skills` | AI SDK 6 breaking changes, Groq, Vercel AI Gateway |

### Community

| Skill | Source | License |
|-------|--------|---------|
| `supabase-nextjs` | [supabase/agent-skills](https://github.com/supabase/agent-skills) | See upstream |
| `mindrally-nextjs-react-typescript` | [Mindrally/skills](https://github.com/Mindrally/skills) | See upstream |
| `mindrally-optimized-nextjs-typescript` | [Mindrally/skills](https://github.com/Mindrally/skills) | See upstream |
| `busirocket-nextjs` | [BusiRocket/agents-skills](https://github.com/BusiRocket/agents-skills) | See upstream |

## Related skills in this repo

- `.cursor/skills/effect.ts-react/` — Effect.ts server/client layers for `apps/test-nextjs`
- `.cursor/skills/react/` — React performance, composition, and UI skills

## Updating

```bash
TMP=$(mktemp -d)
git clone --depth 1 https://github.com/vercel-labs/next-skills.git "$TMP/ns"
for s in next-best-practices next-upgrade next-cache-components; do
  cp -a "$TMP/ns/skills/$s" ".cursor/skills/nextjs/$s"
done
git clone --depth 1 https://github.com/gocallum/nextjs16-agent-skills.git "$TMP/g"
for s in nextjs16-skills shadcn-skills clerk-nextjs-skills authjs-skills mcp-server-skills ai-agents-ui-skills ai-sdk-6-skills; do
  cp -a "$TMP/g/skills/$s" ".cursor/skills/nextjs/$s"
done
```
