---
title: Guard API Routes Before SPA Catch-All
impact: HIGH
impactDescription: Prevents API/HTML confusion, maintains security boundaries
tags: api, spa, routing, security, catch-all
---

## Guard API Routes Before SPA Catch-All

When serving a Single Page Application alongside an API, use structured guards instead of enumerating every SPA route. Always guard `/api/*` before the SPA catch-all to prevent unknown API paths from returning HTML.

**Incorrect (explicit route enumeration):**

```gleam
// router.gleam — every SPA route listed individually
Get, ["orders"] -> serve_admin_html()
Get, ["products"] -> serve_admin_html()
Get, ["customers"] -> serve_admin_html()
Get, ["settings"] -> serve_admin_html()
// ... 20+ more SPA routes
```

This requires server changes every time a client-side route is added.

**Correct (structured guards + catch-all):**

```gleam
// router.gleam — three guards handle everything
// 1. API guard: unknown API routes get 404 JSON, not SPA HTML
_, ["api", ..] -> wisp.not_found()

// 2. Browser artifacts: explicit 404
Get, ["favicon.ico"] -> wisp.not_found()
Get, ["robots.txt"] -> wisp.not_found()

// 3. SPA catch-all: everything else serves the HTML shell
Get, _ -> serve_admin_html()
```

**Benefits:**

- New client routes don't require server changes
- Unknown API paths return 404 JSON (not SPA HTML)
- Client-side router (e.g., Lustre + modem) handles not-found rendering

**Cache headers for SPA HTML shell:**

```gleam
fn serve_admin_html() -> Response {
  wisp.html_response(admin_html, 200)
  |> wisp.set_header("cache-control", "no-cache, must-revalidate")
  |> wisp.set_header("vary", "Accept-Encoding")
}
```

**Path traversal safety:** The catch-all serves a hardcoded HTML shell, never reads files based on user input. Paths that normalize outside `/static/` fall through to the catch-all and get the HTML shell — not file contents. Always verify this invariant with path traversal tests when modifying static/SPA boundaries.
