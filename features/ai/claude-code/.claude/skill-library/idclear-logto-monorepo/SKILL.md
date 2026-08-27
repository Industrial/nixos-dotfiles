---
name: idclear-logto-monorepo
description: idclear monorepo Logto integration — libs/logto Management API client, @idclear/authentication policy, test-nextjs @logto/next proxy and Effect LogtoService, logto-init bootstrap, and e2e Logto flows. Use when changing auth, org roles, connectors, session proxy, or Playwright Logto registration tests in this repo.
---

# idclear monorepo — Logto integration

This repo uses **Logto** (not Clerk or Auth.js). Prefer skills in `.cursor/skills/logto/` over `.cursor/skills/nextjs/clerk-nextjs-skills` or `authjs-skills`.

## Layout

| Area | Path | Role |
|------|------|------|
| Management API / bootstrap | `libs/logto/` | Orgs, users, roles, connectors, OIDC, webhooks, admin bootstrap |
| Auth policy & claims | `libs/authentication/` | Organization role catalog, authorization policy |
| Frontend auth layer | `libs/frontend/src/effect/authentication/` | Logto client, cross-app auth |
| Next.js app | `apps/test-nextjs/` | `@logto/next`, edge proxy, API auth routes |
| Logto seed/init | `apps/logto-init/` | Bootstrap scripts |
| E2E | `apps/e2e-test/` | Logto register/sign-in page objects, mock email |

## OIDC scopes (test-nextjs)

Standard set in `apps/test-nextjs/src/features/auth/server/services/Logto.ts`:

```typescript
const LOGTO_OIDC_SCOPES = [
  'openid', 'profile', 'email', 'offline_access',
  'urn:logto:scope:organizations',
  'urn:logto:scope:organization_roles',
];
```

Organization sync: `LogtoService.syncActiveOrganization(organizationId)`.

## libs/logto modules

- **`client/`** — Management API client (`getManagementClient`)
- **`organizations/`** — create/list/members/invitations
- **`roles/`** — org roles, permissions, grants
- **`connectors/`** — Mailgun email connector, factory resolution, prune mocks
- **`oidc/`** — token introspection, userinfo mapping, Passport strategy
- **`experience/`** — sign-in experience + idclear branding
- **`admin-bootstrap/`** — M2M app, admin user, role assignment
- **`webhooks/`** — hook lifecycle

Run `roam context <symbol>` before editing exported functions.

## test-nextjs auth routes

- Sign-in/out API: `apps/test-nextjs/src/app/api/auth/logto-sign-in/`, `logto-sign-out/`
- Callback: `(app)/callback/route.ts`
- Stale session: `clear-stale-session`, `clearStaleLogtoSession` program
- Edge proxy: `apps/test-nextjs/src/proxy.ts` — rewrites Logto OAuth redirect origins when public URL differs from internal endpoint

## Local dev

- Logto runs via docker compose (see devenv / compose docs)
- `apps/logto-init` bootstraps tenant, apps, connectors
- History notes: `history/logto-shared-origin-local.md`

## E2E patterns

- **Page objects:** `apps/e2e-test/pages/LogtoRegisterPage.ts`, `SignInPage.ts`, `CallbackPage.ts`
- **Mock email:** `apps/e2e-test/lib/logtoMockEmailRecord.ts`, `logtoVerificationEmail.ts`
- **Auth fixtures:** `apps/e2e-test/tests/support/authSession.ts`, `logtoAccessTokenFromPage.ts`
- Playwright config: `apps/e2e-test/playwright.config.ts` (repo pins Playwright 1.52 via nix/devenv)

## Change checklist

1. **App redirect URIs** — Logto Console + env (`baseUrl`, callback path)
2. **Org role catalog** — `libs/authentication` policy if role names/scopes change
3. **Management scripts** — idempotent tests in `libs/logto/**/*.test.ts`
4. **Proxy** — if OAuth Location headers break in local/staging, check proxy rewrite config
5. **E2E** — update page objects when Logto experience UI changes

## MCP

Logto OpenAPI MCP is configured at `https://openapi.logto.io/mcp` (see `.cursor/mcp.json` if enabled). Use for Management API endpoint details.
