---
name: api-gleam
description: REST/JSON API design patterns for Gleam + Wisp + Mist. Use this skill when designing routes, error responses, pagination, request dispatch, or middleware composition.
license: MIT
metadata:
  version: "1.0.0"
  date: February 2026
  abstract: Battle-tested REST/JSON API patterns for Gleam web services using Wisp and Mist. Covers route naming, canonical error responses, HAL pagination, JSON serialization contracts, request dispatch (query params and body type), validation error mapping, SPA routing, and middleware composition.
model: sonnet
memory: project
color: blue
---

# REST/JSON API Patterns (Gleam + Wisp)

Design patterns and conventions for building consistent, maintainable REST APIs in Gleam.

## Stack Context

| Layer       | Tool           | Role                                  |
| ----------- | -------------- | ------------------------------------- |
| Language    | Gleam          | Backend application code              |
| HTTP server | Mist           | Erlang-based HTTP server              |
| Framework   | Wisp           | Request/response helpers, middleware  |
| JSON        | gleam/json     | JSON encoding                         |
| Decoding    | gleam/decode   | Type-safe JSON decoding               |
| Errors      | error_response | Centralized error → HTTP response     |

## Core Principles

- **REST nouns, not verbs** — routes use plural nouns and sub-resources
- **Canonical error shape** — every error response uses `{"error": "Kind", "message": "text"}`
- **Centralized error handling** — never build ad-hoc JSON error responses in handlers
- **Consistent serialization** — shared helpers for timestamps, metadata, optional fields
- **Middleware as closures** — auth → rate limit → handler, each layer wraps the next

## When to Apply

Reference these patterns when:

- Designing new API routes or renaming existing ones
- Returning error responses from handlers or middleware
- Implementing paginated list endpoints
- Serializing domain types to JSON
- Consolidating multiple GET or POST endpoints
- Handling validation errors vs decode errors
- Setting up SPA routing alongside API routes
- Composing middleware (auth, rate limiting, usage tracking)

## Reference Categories by Priority

| Priority | Category           | Impact   | Prefix        |
| -------- | ------------------ | -------- | ------------- |
| 1        | Route Design       | HIGH     | `route-`      |
| 2        | Error Handling     | CRITICAL | `error-`      |
| 3        | Serialization      | HIGH     | `json-`       |
| 4        | Pagination         | MEDIUM   | `pagination-` |
| 5        | Request Dispatch   | MEDIUM   | `dispatch-`   |
| 6        | Router Patterns    | MEDIUM   | `router-`     |

## Token Efficiency

**Follow `references/token-efficiency.md` rules.** When reviewing or writing API code:

1. Grep for specific patterns (e.g., `error_response.handle`, `wisp.require_json`, `hal.page`) instead of reading all handler files
2. Use `git diff --name-only` to scope reviews to changed handler/router files only
3. Read targeted line ranges around Grep matches, not entire controllers

## How to Use

Read individual reference files in `references/` for detailed explanations and Gleam examples. Each reference contains:

- Brief explanation of the pattern and why it matters
- Incorrect example showing the anti-pattern
- Correct example showing the recommended approach
- When to apply and edge cases

## Available References

**Route Design** (`route-`):

- `references/route-naming.md`

**Error Handling** (`error-`, `validation-`):

- `references/error-responses.md`
- `references/validation-errors.md`

**Serialization** (`json-`):

- `references/json-serialization.md`

**Pagination** (`pagination-`):

- `references/pagination-hal.md`

**Request Dispatch** (`dispatch-`):

- `references/query-dispatch.md`
- `references/body-dispatch.md`

**Router Patterns** (`router-`):

- `references/spa-routing.md`
- `references/middleware-composition.md`

## Decision Tree

**"I need to..."**

- ...name a new route → `route-naming.md`
- ...return an error from a handler → `error-responses.md`
- ...distinguish 400 vs 422 → `validation-errors.md`
- ...add pagination to a list endpoint → `pagination-hal.md`
- ...serialize timestamps or metadata → `json-serialization.md`
- ...merge multiple GET endpoints → `query-dispatch.md`
- ...dispatch POST by body type → `body-dispatch.md`
- ...serve SPA alongside API → `spa-routing.md`
- ...compose auth + rate limiting → `middleware-composition.md`

---

_9 reference files across 6 categories_

## References

- <https://hexdocs.pm/wisp/>
- <https://hexdocs.pm/mist/>
- <https://hexdocs.pm/gleam_json/>
