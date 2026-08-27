# Wisp

Practical Gleam web framework for HTTP backends: handlers and middleware.

**Package:** [wisp on Hex](https://hex.pm/packages/wisp)  
**Docs:** [HexDocs](https://hexdocs.pm/wisp/)

## When to use

- HTTP servers (APIs, static sites, server-rendered pages).
- Handlers that take a request and return a response; middleware for logging, static files, etc.

## Entrypoints

- **wisp** — `type Request`, `type Response`. Handlers: `request -> Response`. Example: `wisp.ok()`, `wisp.not_found()`, `wisp.response(status)`, `wisp.json_response(body, status)`. Middleware applied with `use <- wisp.some_middleware(...)` in the handler.
- **Middleware:** e.g. `wisp.log_request(request)`, `wisp.serve_static(request, under: "/static", from: "/public")`. Middleware wraps the next handler and returns a response.

## Pattern

One main handler that uses `use <- middleware(...)` for cross-cutting concerns, then returns a `Response`. Context (e.g. DB, config) can be passed as an extra argument to the handler.
