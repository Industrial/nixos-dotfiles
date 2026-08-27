---
name: logto-management-api
description: Configure and automate Logto via the Management API — users, organizations, roles, applications, connectors, sign-in experience, webhooks, and M2M apps. Use when seeding tenants, provisioning org roles, syncing connectors, or scripting Logto admin tasks. Triggers on openapi.logto.io, Management API, M2M application, organization roles, connector factories.
---

# Logto Management API

OpenAPI: [openapi.logto.io](https://openapi.logto.io) · Markdown export: [openapi.logto.io/source.md](https://openapi.logto.io/source.md) · MCP: `https://openapi.logto.io/mcp`

**Cloud base URL:** `https://[tenant_id].logto.app`  
**OSS:** Use `/api/swagger.json` on your instance (docs target Cloud; paths align for OSS).

## Authentication

Create an **Machine-to-machine (M2M)** application in Logto Console. Exchange client credentials for a bearer token, then call Management API endpoints with `Authorization: Bearer <token>`.

Typical bootstrap flow:
1. Create M2M app + assign Management API roles/scopes
2. Obtain access token (client credentials grant)
3. Call resource endpoints (users, orgs, roles, connectors, …)

## High-value endpoint groups

| Group | Use for |
|-------|---------|
| **Users** | CRUD, passwords, roles, identities, sessions |
| **Organizations** | Multi-tenant membership, JIT, org applications |
| **Organization roles / scopes** | Tenant RBAC (`organization_roles` claim format `<org_id>:<role>`) |
| **Applications** | SPA/traditional/M2M apps, secrets, redirect URIs |
| **Resources & roles** | API resources, scopes, user/app role assignment |
| **Connectors** | Email/SMS/social; factory list + enable/configure |
| **Sign-in experience** | Branding, identifiers, password policy |
| **Hooks / webhooks** | Event subscriptions |
| **Experience API** | Programmatic sign-in flows (separate from Management API) |

## Organizations + RBAC patterns

1. Create organization scopes and organization roles
2. Link scopes to roles; assign roles to users in an org
3. Request `urn:logto:scope:organizations` and `urn:logto:scope:organization_roles` in app OIDC scopes
4. ID token / userinfo returns `organizations`, `organization_roles` (and optionally `organization_data`)

Organization token (app SDK): `getOrganizationToken(config, organizationId)` — JWT for org-scoped API access.

## Connectors

- **List factories:** `GET /connector-factors` — available connector types
- **Create/enable:** `POST /connectors` then configure metadata (SMTP, Mailgun, OAuth, etc.)
- **Test:** connector test endpoints before enabling in production

## Sign-in experience

- Default experience: `GET/PATCH /sign-in-exp`
- Application-level overrides available per application
- Custom phrases, captcha provider, JWT customizers under **Configs**

## Scripting tips

- Prefer idempotent upserts (get-by-name → create or patch)
- Paginate list endpoints; filter where supported
- Audit logs available for debugging admin changes
- For local OSS dev: align endpoint with docker-compose Logto service URL

## SDK vs raw HTTP

Official `@logto/node` and language SDKs wrap Management API calls. For monorepo automation, a thin Effect/fetch client with typed paths from OpenAPI is often sufficient.

## Related docs

- [Management API authentication](https://openapi.logto.io/authentication)
- [Organizations](https://docs.logto.io/organizations)
- [Connectors](https://docs.logto.io/connectors)
