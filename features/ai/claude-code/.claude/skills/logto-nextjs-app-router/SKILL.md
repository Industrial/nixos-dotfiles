---
name: logto-nextjs-app-router
description: Integrate Logto authentication with Next.js App Router using @logto/next. Use when configuring sign-in/sign-out, OAuth callbacks, session cookies, scopes and claims, API resource tokens, organization tokens, external session storage, or protected RSC routes. Triggers on LogtoNextConfig, handleSignIn, getLogtoContext, signIn, signOut, getAccessToken, getOrganizationToken.
---

# Logto + Next.js App Router

Official guide: [docs.logto.io/quick-starts/next-app-router](https://docs.logto.io/quick-starts/next-app-router). Sample: [logto-io/js next-server-actions-sample](https://github.com/logto-io/js/tree/master/packages/next-server-actions-sample).

## Install

```bash
npm i @logto/next
```

## Config (`app/logto.ts`)

```typescript
import { UserScope, type LogtoNextConfig } from '@logto/next';

export const logtoConfig: LogtoNextConfig = {
  appId: '<application-id>',
  appSecret: '<app-secret>',
  endpoint: '<logto-endpoint>', // e.g. http://localhost:3001
  baseUrl: '<nextjs-base-url>', // e.g. http://localhost:3000
  cookieSecret: 'complex_password_at_least_32_characters_long',
  cookieSecure: process.env.NODE_ENV === 'production',
  scopes: [UserScope.Email, UserScope.Organizations],
  resources: ['https://api.example.com'],
};
```

**Cookie secret:** Must be ≥32 chars. Missing/short secret → `TypeError: Either sessionWrapper or encryptionKey must be provided for CookieStorage`.

**Redirect URIs (Logto Console):** Add `{baseUrl}/callback` and post sign-out redirect (often `{baseUrl}/`).

## Callback route

```typescript
// app/callback/route.ts
import { handleSignIn } from '@logto/next/server-actions';
import { redirect } from 'next/navigation';
import type { NextRequest } from 'next/server';
import { logtoConfig } from '../logto';

export async function GET(request: NextRequest) {
  await handleSignIn(logtoConfig, request.nextUrl.searchParams);
  redirect('/');
}
```

## Sign-in / sign-out from RSC

Pass server actions from Server Components to client button components (inline `'use server'` in Client Components is invalid):

```typescript
import { getLogtoContext, signIn, signOut } from '@logto/next/server-actions';
```

## Claims and userinfo

- Default scopes: `openid`, `profile`, `offline_access`.
- `getLogtoContext(logtoConfig)` returns `claims` from ID token.
- Network-only claims (`custom_data`, etc.): `getLogtoContext(logtoConfig, { fetchUserInfo: true })`.
- Extended org claims: request `UserScope.Organizations` and `urn:logto:scope:organization_roles`.

## API resource tokens

```typescript
import { getAccessToken, getAccessTokenRSC } from '@logto/next/server-actions';

// Client via server action (persists refreshed tokens in cookies)
await getAccessToken(logtoConfig, 'https://api.example.com');

// RSC — refreshes but does NOT persist new access token to cookie (Next.js limitation)
await getAccessTokenRSC(logtoConfig, 'https://api.example.com');
```

Prefer client + server action for token refresh persistence, or use `sessionWrapper` with Redis/KV.

## Organization tokens

Requires `UserScope.Organizations` in config. Use `getOrganizationToken` / `getOrganizationTokenRSC` with organization ID.

## Protected routes

`signIn` modifies cookies — call from a route handler, not directly in RSC:

```typescript
// app/sign-in/route.ts — GET calls signIn(logtoConfig)
// app/protected/page.tsx — if !isAuthenticated redirect('/sign-in')
```

## External session storage

When cookie session grows too large (multiple org sessions), implement `SessionWrapper` (`wrap`/`unwrap`) and pass `sessionWrapper` in config. Cookie stores session ID; data lives in Redis/DB.

## Common pitfalls

| Issue | Fix |
|-------|-----|
| Cookie secret too short | ≥32 char `cookieSecret` or env var |
| RSC token not persisting | Use server actions or external `sessionWrapper` |
| Missing org claims | Add org scopes; may need `fetchUserInfo: true` |
| Inline server action in client component | Pass action via props from RSC |

## Further reading

- [RBAC / API resources](https://docs.logto.io/authorization/role-based-access-control)
- [Organizations](https://docs.logto.io/organizations)
- [Custom ID token claims](https://docs.logto.io/developers/custom-id-token)
