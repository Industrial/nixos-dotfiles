# Web Framework with wisp

Use `wisp` + `wisp_mist` for building web applications on the Erlang target.

## Installation

```sh
gleam add wisp@2
gleam add wisp_mist@1
gleam add mist@5
```

## Architecture

wisp is a practical web framework built on three concepts:

- **Handlers** — functions that take a `Request` and return a `Response`
- **Middleware** — functions that wrap handlers using `use` syntax
- **Routing** — pattern matching on `path_segments` and `req.method`

wisp is server-agnostic. The `wisp_mist` adapter connects wisp handlers to the
mist HTTP server.

## Quick Start

```gleam
import gleam/erlang/process
import mist
import wisp
import wisp_mist

pub fn main() {
  wisp.configure_logger()
  let secret_key_base = wisp.random_string(64)

  let assert Ok(_) =
    wisp_mist.handler(handle_request, secret_key_base)
    |> mist.new
    |> mist.port(8000)
    |> mist.start

  process.sleep_forever()
}

fn handle_request(req: wisp.Request) -> wisp.Response {
  case wisp.path_segments(req) {
    [] -> wisp.ok() |> wisp.string_body("Hello!")
    ["health"] -> wisp.ok() |> wisp.json_body("{\"status\":\"ok\"}")
    _ -> wisp.not_found()
  }
}
```

## Types

### Request & Response

```gleam
/// Request with a wisp Connection body (lazy — body not yet read)
pub type Request = request.Request(Connection)

/// Response with a wisp Body
pub type Response = response.Response(Body)

pub type Body {
  Text(String)
  Bytes(BytesTree)
  File(path: String, offset: Int, limit: Option(Int))
}
```

### FormData

```gleam
pub type FormData {
  FormData(
    values: List(#(String, String)),
    files: List(#(String, UploadedFile)),
  )
}

pub type UploadedFile {
  UploadedFile(file_name: String, path: String)
}
```

### Cookie Security

```gleam
pub type Security {
  PlainText  // base64, readable by client
  Signed     // HMAC-signed with secret key base
}
```

## Routing

wisp uses Gleam's native pattern matching — no DSL or router macros.

### Path Segments

```gleam
case wisp.path_segments(req) {
  [] -> home_page(req)
  ["users"] -> users(req)
  ["users", id] -> show_user(req, id)
  ["users", id, "posts"] -> user_posts(req, id)
  ["api", "v1", ..rest] -> api_v1(req, rest)
  _ -> wisp.not_found()
}
```

### Method Dispatch

```gleam
import gleam/http.{Delete, Get, Post}

fn users(req: wisp.Request) -> wisp.Response {
  case req.method {
    Get -> list_users(req)
    Post -> create_user(req)
    _ -> wisp.method_not_allowed(allowed: [Get, Post])
  }
}
```

### Method Override (HTML Forms)

```gleam
// In middleware — converts POST with ?_method=DELETE to DELETE
let req = wisp.method_override(req)
```

HTML forms only support GET and POST. This enables PUT, PATCH, DELETE via
the `_method` query parameter on POST requests.

### Query Parameters

```gleam
let params = wisp.get_query(req)
// [#("page", "2"), #("sort", "name")]
```

## Response Builders

### Status Code Shortcuts

```gleam
wisp.ok()                    // 200
wisp.created()               // 201
wisp.accepted()              // 202
wisp.no_content()            // 204
wisp.redirect(to: "/login")  // 303 See Other
wisp.permanent_redirect(to: "/new-url")  // 308

wisp.bad_request(detail: "Invalid input")  // 400
wisp.not_found()                            // 404
wisp.method_not_allowed(allowed: [Get, Post])  // 405
wisp.content_too_large()                    // 413
wisp.unsupported_media_type(accept: ["application/json"])  // 415
wisp.unprocessable_content()                // 422
wisp.internal_server_error()                // 500

wisp.response(status: 418)  // any status code
```

### Body Setters

```gleam
// Set body on an existing response
wisp.ok()
|> wisp.html_body("<h1>Hello</h1>")  // sets text/html content-type

wisp.ok()
|> wisp.json_body("{\"ok\":true}")   // sets application/json content-type

wisp.ok()
|> wisp.string_body("plain text")    // no content-type set automatically

wisp.ok()
|> wisp.string_tree_body(string_tree) // no content-type set automatically
```

### Convenience Constructors

```gleam
// Create response with body and status in one call
wisp.html_response("<h1>Hello</h1>", 200)
wisp.json_response("{\"ok\":true}", 200)
```

### File Downloads

```gleam
// Stream file from disk (efficient, not loaded into memory)
wisp.ok()
|> wisp.file_download(named: "report.pdf", from: "/path/to/file.pdf")

// Send in-memory bytes as a download
wisp.ok()
|> wisp.file_download_from_memory(named: "data.csv", containing: csv_bytes)
```

### Headers

```gleam
wisp.ok()
|> wisp.set_header("x-request-id", request_id)
|> wisp.set_header("cache-control", "max-age=3600")
```

## Request Body Reading

All body-reading functions are middleware — they handle error responses
(400, 413, 415) automatically.

### String Body

```gleam
fn create_comment(req: wisp.Request) -> wisp.Response {
  use body <- wisp.require_string_body(req)
  // body: String — 400 if not UTF-8, 413 if too large
  wisp.created() |> wisp.string_body("Created")
}
```

### BitArray Body

```gleam
use body <- wisp.require_bit_array_body(req)
// body: BitArray — 413 if too large
```

### JSON Body

```gleam
use json <- wisp.require_json(req)
// json: Dynamic — 415 if not application/json, 400 if invalid JSON, 413 if too large
case decode.run(json, user_decoder()) {
  Ok(user) -> // ...
  Error(_) -> wisp.unprocessable_content()
}
```

### Form Data (URL-encoded & Multipart)

```gleam
use form <- wisp.require_form(req)
// form: FormData — values + uploaded files
// 415 if wrong content-type, 413 if too large

// Access form values
case list.key_find(form.values, "name") {
  Ok(name) -> // ...
  Error(_) -> wisp.bad_request(detail: "Missing name")
}

// Access uploaded files
case list.key_find(form.files, "avatar") {
  Ok(upload) -> {
    // upload.file_name: String (client-reported, never trust)
    // upload.path: String (temp file on server)
    wisp.created()
  }
  Error(_) -> wisp.bad_request(detail: "Missing avatar")
}
```

### Content-Type Validation

```gleam
use <- wisp.require_content_type(req, "application/xml")
// 415 if content-type doesn't match
```

### Raw Body Reading

```gleam
// Returns Result instead of middleware pattern
case wisp.read_body_bits(req) {
  Ok(bits) -> // ...
  Error(Nil) -> wisp.content_too_large()
}
```

### Size Limits

```gleam
let req = req
  |> wisp.set_max_body_size(1_000_000)      // 1 MB body limit
  |> wisp.set_max_files_size(10_000_000)     // 10 MB total files
  |> wisp.set_read_chunk_size(65_536)        // 64 KB read chunks
```

## Middleware

Middleware wraps handlers using Gleam's `use` syntax. Each middleware accepts
a continuation and can modify the request, response, or short-circuit.

### Standard Middleware Stack

```gleam
pub fn middleware(
  req: wisp.Request,
  handle_request: fn(wisp.Request) -> wisp.Response,
) -> wisp.Response {
  let req = wisp.method_override(req)
  use <- wisp.log_request(req)
  use <- wisp.rescue_crashes
  use req <- wisp.handle_head(req)
  use req <- wisp.csrf_known_header_protection(req)
  use <- wisp.serve_static(req, under: "/static", from: static_dir)
  handle_request(req)
}
```

### log_request

```gleam
use <- wisp.log_request(req)
```

Logs method, path, and response status code.

### rescue_crashes

```gleam
use <- wisp.rescue_crashes
```

Catches panics and returns 500 instead of crashing the process.

### handle_head

```gleam
use req <- wisp.handle_head(req)
```

Converts HEAD requests to GET, runs handler, discards body.

### serve_static

```gleam
use <- wisp.serve_static(req, under: "/static", from: ctx.static_directory)
```

Serves files from a directory when the path starts with the prefix. Sets
content-type automatically. Blocks path traversal attacks.

### require_method

```gleam
use <- wisp.require_method(req, Get)
// 405 if method doesn't match
```

### csrf_known_header_protection

```gleam
use req <- wisp.csrf_known_header_protection(req)
```

Validates `host` against `origin`/`referer` headers per OWASP standards.

### content_security_policy_protection

```gleam
use nonce <- wisp.content_security_policy_protection
// nonce: String — unique per-request, use in script/style tags
```

## Cookies

### Set a Cookie

```gleam
wisp.ok()
|> wisp.set_cookie(req, "session_id", session_id, wisp.Signed, 86_400)
//                  req   name          value        security    max_age (seconds)
```

- `Signed` — tamper-proof via HMAC (use for session data)
- `PlainText` — base64-encoded, readable by client (use for preferences)
- Set `max_age` to `0` to delete a cookie

### Get a Cookie

```gleam
case wisp.get_cookie(req, "session_id", wisp.Signed) {
  Ok(session_id) -> // valid, signature verified
  Error(Nil) -> // not found or invalid signature
}
```

## Secret Key Base & Signing

The secret key base is set by `wisp_mist.handler` and used for cookie signing
and message signing.

```gleam
// Sign a message (content readable, but tamper-proof)
let signed = wisp.sign_message(req, message_bits, crypto.Sha256)

// Verify a signed message
case wisp.verify_signed_message(req, signed) {
  Ok(original_bits) -> // valid
  Error(Nil) -> // tampered or invalid
}
```

## Temporary Files

```gleam
// Create a temp file (auto-cleaned after response)
let assert Ok(path) = wisp.new_temporary_file(req)

// Manual cleanup
let assert Ok(Nil) = wisp.delete_temporary_files(req)
```

## Logging

```gleam
// Configure at startup
wisp.configure_logger()
wisp.set_logger_level(wisp.DebugLevel)

// Log at different levels
wisp.log_debug("Processing request")
wisp.log_info("User logged in: " <> user_id)
wisp.log_warning("Rate limit approaching")
wisp.log_error("Database connection failed")
wisp.log_critical("System overloaded")
wisp.log_alert("Disk space critical")
wisp.log_emergency("System shutting down")
```

## HTML Escaping

```gleam
wisp.escape_html("<script>alert('xss')</script>")
// "&lt;script&gt;alert(&#39;xss&#39;)&lt;/script&gt;"
```

## Utilities

```gleam
// Random string for secrets, tokens, etc.
let token = wisp.random_string(32)

// Get priv directory for templates, static assets
let assert Ok(priv) = wisp.priv_directory("my_app")

// Parse range header
case wisp.parse_range_header("bytes=0-499") {
  Ok(wisp.Range(offset: 0, limit: Some(500))) -> // ...
  Error(Nil) -> // invalid
}
```

## Testing with wisp/simulate

```gleam
import wisp/simulate

pub fn home_page_test() {
  let response =
    simulate.request(Get, "/")
    |> router.handle_request

  response.status
  |> should.equal(200)

  simulate.read_body(response)
  |> should.equal("Hello!")
}

pub fn create_user_test() {
  let response =
    simulate.browser_request(Post, "/users")  // includes origin header for CSRF
    |> simulate.json_body(json.object([
      #("name", json.string("Alice")),
    ]))
    |> router.handle_request

  response.status
  |> should.equal(201)
}

pub fn file_upload_test() {
  let response =
    simulate.browser_request(Post, "/upload")
    |> simulate.multipart_body(
      values: [#("title", "Photo")],
      files: [
        #("image", simulate.FileUpload(
          file_name: "cat.jpg",
          content_type: "image/jpeg",
          content: file_bytes,
        )),
      ],
    )
    |> router.handle_request

  response.status
  |> should.equal(201)
}

pub fn session_test() {
  // First request: login
  let login_req = simulate.browser_request(Post, "/login")
    |> simulate.form_body([#("user", "alice"), #("pass", "secret")])
  let login_resp = router.handle_request(login_req)

  // Second request: carry session cookies forward
  let profile_req = simulate.request(Get, "/profile")
    |> simulate.session(login_req, login_resp)
  let profile_resp = router.handle_request(profile_req)

  profile_resp.status |> should.equal(200)
}
```

### Simulate Functions

```gleam
simulate.request(method, path)          // basic test request
simulate.browser_request(method, path)  // with origin header (for CSRF)
simulate.session(next_req, prev_req, prev_resp)  // carry cookies forward

// Set body
simulate.string_body(req, "text")
simulate.html_body(req, "<h1>Hi</h1>")
simulate.json_body(req, json.object([...]))
simulate.form_body(req, [#("key", "value")])
simulate.bit_array_body(req, <<1, 2, 3>>)
simulate.multipart_body(req, values: [...], files: [...])

// Set headers/cookies
simulate.header(req, "authorization", "Bearer token")
simulate.cookie(req, "name", "value", wisp.Signed)

// Read response
simulate.read_body(response)       // -> String
simulate.read_body_bits(response)  // -> BitArray
```

## Complete Application Example

```gleam
//// src/app.gleam
import gleam/erlang/process
import app/router
import app/web
import mist
import wisp
import wisp_mist

pub fn main() {
  wisp.configure_logger()
  let secret_key_base = wisp.random_string(64)
  let assert Ok(priv) = wisp.priv_directory("my_app")
  let ctx = web.Context(static_directory: priv <> "/static")

  let assert Ok(_) =
    wisp_mist.handler(router.handle_request(_, ctx), secret_key_base)
    |> mist.new
    |> mist.port(8000)
    |> mist.start

  process.sleep_forever()
}
```

```gleam
//// src/app/web.gleam
import wisp

pub type Context {
  Context(static_directory: String)
}

pub fn middleware(
  req: wisp.Request,
  ctx: Context,
  handle_request: fn(wisp.Request) -> wisp.Response,
) -> wisp.Response {
  let req = wisp.method_override(req)
  use <- wisp.log_request(req)
  use <- wisp.rescue_crashes
  use req <- wisp.handle_head(req)
  use req <- wisp.csrf_known_header_protection(req)
  use <- wisp.serve_static(req, under: "/static", from: ctx.static_directory)
  handle_request(req)
}
```

```gleam
//// src/app/router.gleam
import gleam/http.{Delete, Get, Post}
import gleam/json
import gleam/dynamic/decode
import app/web.{type Context}
import wisp.{type Request, type Response}

pub fn handle_request(req: Request, ctx: Context) -> Response {
  use req <- web.middleware(req, ctx)
  case wisp.path_segments(req) {
    [] -> home(req)
    ["api", "users"] -> users(req)
    ["api", "users", id] -> user(req, id)
    _ -> wisp.not_found()
  }
}

fn home(req: Request) -> Response {
  use <- wisp.require_method(req, Get)
  wisp.ok() |> wisp.html_body("<h1>Welcome</h1>")
}

fn users(req: Request) -> Response {
  case req.method {
    Get -> {
      let data = json.to_string(json.array([], json.string))
      wisp.json_response(data, 200)
    }
    Post -> {
      use json <- wisp.require_json(req)
      case decode.run(json, user_decoder()) {
        Ok(user) -> {
          let data = json.to_string(encode_user(user))
          wisp.json_response(data, 201)
        }
        Error(_) -> wisp.unprocessable_content()
      }
    }
    _ -> wisp.method_not_allowed(allowed: [Get, Post])
  }
}
```

## Best Practices

1. **Use the standard middleware stack** — `log_request`, `rescue_crashes`,
   `handle_head`, and `csrf_known_header_protection` should be in every app
2. **Pattern match for routing** — no need for a router library, Gleam's
   pattern matching on `path_segments` is expressive and type-safe
3. **Pass context as a parameter** — database connections, config, etc. go in
   a `Context` type passed to the handler via partial application
4. **Use `Signed` cookies for sessions** — `PlainText` cookies are readable
   by the client
5. **Set body size limits** — `set_max_body_size` and `set_max_files_size`
   prevent denial-of-service via large uploads
6. **Use `wisp/simulate` for testing** — test handlers directly without
   starting a server
7. **Escape user content** — use `wisp.escape_html` when including user input
   in HTML responses
