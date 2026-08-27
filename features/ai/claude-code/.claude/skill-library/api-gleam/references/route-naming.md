---
title: Use Plural Nouns and Sub-Resources for REST Routes
impact: HIGH
impactDescription: Consistent, predictable API surface for clients
tags: api, rest, routes, naming
---

## Use Plural Nouns and Sub-Resources for REST Routes

REST routes should use plural nouns and sub-resources, not hyphenated verbs. Resource-oriented paths are predictable, composable, and follow HTTP semantics where the method (GET, POST, DELETE) conveys the action.

**Incorrect (verbs in route paths):**

```gleam
// router.gleam — verb-based routes
Post, ["auth", "register-with-invitation"] -> auth.register_with_invitation(req, db)
Get, ["invitations", "validate", token] -> invitations.validate(req, db, token)
```

**Correct (noun-based routes with sub-resources):**

```gleam
// router.gleam — resource-oriented routes
Post, ["auth", "registrations", "invitation"] -> auth.register_with_invitation(req, db)
Get, ["invitations", "tokens", token] -> invitations.get_token(req, db, token)
```

**Guidelines:**

- Use plural nouns: `/orders`, `/invitations`, `/customers`
- Use sub-resources for relationships: `/orders/:id/shipments`
- Let HTTP methods convey the action: `POST /orders` (create), `DELETE /orders/:id` (remove)
- When removing alias routes (e.g., `/team/invitations` → `/invitations`), document in API changelog and use `feat!:` commit prefix for breaking changes
