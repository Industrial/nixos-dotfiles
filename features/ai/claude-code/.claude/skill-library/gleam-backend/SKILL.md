---
name: gleam-backend
description: Gleam backend development skill for the Erlang target. Covers Wisp, Mist, OTP actors, Supervision trees, Squirrel/Parrot SQL codegen integration, JWT auth, and HTTP runners. Use when building server-side logic in Kafka.
---

# Gleam Backend Best Practices

Skill for Gleam server-side development on the Erlang target. **Read the relevant reference before writing code.**

## Token Efficiency
**All agents and commands using this skill MUST follow `references/token-efficiency.md` (from core).** Use `Read` and `Grep` tools with targeted reads instead of reading entire files.

## Reference routing — by task

| Task                          | References to read                                                               |
|-------------------------------|----------------------------------------------------------------------------------|
| Building Wisp HTTP handlers   | `wisp-framework.md` + `http-logging-middleware.md`                               |
| SQL Database access           | `squirrel-guide.md` or `parrot-guide.md`                                         |
| Creating OTP Actors           | `otp.md` + `otp-advanced.md`                                                     |
| OTP Supervision               | `otp-supervision.md`                                                             |
| DB Migrations                 | `cigogne.md`                                                                     |
| API Auth / JWT                | `jwt-ywt.md` + `auth.md`                                                         |
| Making outbound HTTP calls    | `http-runner.md`                                                                 |

## Reference routing — by topic

| Topic                                    | Reference                                       |
|------------------------------------------|-------------------------------------------------|
| HTTP Server config (mist)                | `mist-server.md`                                |
| Error Handling (3-tier)                  | `three-tier-error-handling.md`                  |
| Decoder Defaults Anti-Pattern            | `decoder-defaults-anti-pattern.md`              |
| Storage (S3, Image, PDF)                 | `bucket-s3.md` + `ansel-image.md` + `paddlefish-pdf.md` |
| Midas algebraic effects                  | `midas-effect-task.md`                          |

## Core Backend Principles

1. **Errors as Values** — use 3-tier error handling (AppError), never exceptions.
2. **SQL is the Contract** — never edit generated `sql.gleam` files. Fix the `.sql` source.
3. **No IO in Core** — keep database access in handlers/services, separate from pure business logic.

## Review Commands

**When to use `/otp-review`:**
- After creating new actors or supervision trees.
- When experiencing timeouts, deadlocks, or memory leaks.
