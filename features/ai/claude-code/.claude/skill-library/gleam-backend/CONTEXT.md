# gleam-backend — Gleam Server-Side Skill
> Last updated: 2026-05-16

Covers the Erlang target, including OTP, Wisp, Mist, SQL codegen (Squirrel/Parrot), and integrations. 

Inherits: `skills/CONTEXT.md`.

## Layout
```
gleam-backend/
├── SKILL.md                         # Main prompt with decision trees
└── references/                      # Erlang target — HTTP, DB, OTP, auth
    ├── wisp-framework.md        # Wisp routing, middleware, responses
    ├── mist-server.md           # Mist HTTP server config
    ├── otp.md                   # OTP actors: basics, state, messages
    ├── otp-supervision.md       # Supervision trees, strategies
    ├── otp-advanced.md          # Selectors, timers, ETS
    ├── squirrel-guide.md        # SQL codegen (Squirrel)
    ├── parrot-guide.md          # SQL codegen (Parrot/sqlc)
    ├── cigogne.md               # Database migrations
    ├── three-tier-error-handling.md
    ├── decoder-defaults-anti-pattern.md
    ├── http-logging-middleware.md
    ├── http-runner.md           # HTTP client runner pattern
    ├── jwt-ywt.md               # JWT authentication
    ├── auth.md                  # Password hashing, timestamps
    ├── bucket-s3.md             # S3 / object storage
    ├── ansel-image.md           # Image processing
    ├── paddlefish-pdf.md        # PDF generation
    └── midas-effect-task.md     # Midas algebraic effects
```

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

## Common Backend Gotchas
### SQL codegen (Parrot/Squirrel)
- **SQL is the contract, Gleam bends to it.** Never edit generated `sql.gleam` files. Fix the `.sql` source, regenerate, then update handlers to match the new types.

### Wisp HTTP
- **`wisp.path_segments(req)` returns the FULL path**, not relative to mount point.
- **There is no `get_header`.** Use `list.key_find(req.headers, name)`. Header names are lowercase.
