# HTTP Server with mist

Use `mist` as the HTTP server for Gleam web applications. Supports HTTP,
WebSockets, Server-Sent Events, TLS, file serving, and OTP supervision.

## Installation

```sh
gleam add mist@5
```

For use with wisp, also add:

```sh
gleam add wisp@2
gleam add wisp_mist@1
```

## Architecture

mist uses a **builder pattern** for server configuration:

1. Create a builder with `mist.new(handler)`
2. Configure with `port`, `bind`, `with_tls`, etc.
3. Start with `mist.start` or integrate with `mist.supervised`

The handler receives a `Request(Connection)` where the body is lazy — you must
call `mist.read_body` or `mist.stream` to read it.

## Quick Start

```gleam
import gleam/bytes_tree
import gleam/erlang/process
import gleam/http/request
import gleam/http/response
import mist

pub fn main() {
  let assert Ok(_) =
    mist.new(handle_request)
    |> mist.port(4000)
    |> mist.start

  process.sleep_forever()
}

fn handle_request(
  req: request.Request(mist.Connection),
) -> response.Response(mist.ResponseData) {
  response.new(200)
  |> response.set_body(mist.Bytes(bytes_tree.from_string("Hello!")))
}
```

## Core Types

### Connection

```gleam
pub type Connection  // opaque
```

The request body type. Body is NOT read until you call `read_body` or `stream`.

### ResponseData

```gleam
pub type ResponseData {
  Bytes(BytesTree)                            // standard response
  Chunked(Yielder(BytesTree))                 // streaming chunks
  File(descriptor: FileDescriptor, offset: Int, length: Int)  // sendfile
  Websocket(Selector(Down))                   // WebSocket upgrade
  ServerSentEvents(Selector(Down))            // SSE upgrade
}
```

### ReadError

```gleam
pub type ReadError {
  ExcessBody      // body exceeds size limit
  MalformedBody   // socket error or bad chunked encoding
}
```

### ConnectionInfo & IpAddress

```gleam
pub type ConnectionInfo {
  ConnectionInfo(port: Int, ip_address: IpAddress)
}

pub type IpAddress {
  IpV4(Int, Int, Int, Int)
  IpV6(Int, Int, Int, Int, Int, Int, Int, Int)
}
```

### Chunk (Streaming Body)

```gleam
pub type Chunk {
  Chunk(data: BitArray, consume: fn(Int) -> Result(Chunk, ReadError))
  Done
}
```

## Server Configuration

### Builder Pattern

```gleam
mist.new(handler)
|> mist.port(8000)                    // default: 4000
|> mist.bind("0.0.0.0")              // default: "0.0.0.0"
|> mist.with_ipv6                     // listen on IPv4 + IPv6
|> mist.after_start(fn(port, scheme, ip) {
  io.println("Listening on " <> mist.ip_address_to_string(ip)
    <> ":" <> int.to_string(port))
})
|> mist.start
```

### TLS / HTTPS

```gleam
mist.new(handler)
|> mist.port(443)
|> mist.with_tls(certfile: "/path/to/cert.pem", keyfile: "/path/to/key.pem")
|> mist.start
```

### OTP Supervision

```gleam
let child_spec =
  mist.new(handler)
  |> mist.port(4000)
  |> mist.supervised

// Add child_spec to your supervisor children
```

### Auto-Read Request Bodies

```gleam
// Handler receives Request(BitArray) instead of Request(Connection)
let handler = fn(req: request.Request(BitArray)) -> response.Response(mist.ResponseData) {
  // req.body is already read as BitArray
  response.new(200) |> response.set_body(mist.Bytes(bytes_tree.new()))
}

mist.new(handler)
|> mist.read_request_body(
  bytes_limit: 1_000_000,  // 1 MB max
  failure_response: response.new(413)
    |> response.set_body(mist.Bytes(bytes_tree.from_string("Too large"))),
)
|> mist.port(4000)
|> mist.start
```

## Request Body Reading

### Read Full Body

```gleam
case mist.read_body(req, max_body_limit: 10_000_000) {
  Ok(req) -> {
    // req.body is now BitArray
    let body = req.body
    response.new(200) |> response.set_body(mist.Bytes(bytes_tree.new()))
  }
  Error(mist.ExcessBody) ->
    response.new(413) |> response.set_body(mist.Bytes(bytes_tree.new()))
  Error(mist.MalformedBody) ->
    response.new(400) |> response.set_body(mist.Bytes(bytes_tree.new()))
}
```

### Stream Body in Chunks

```gleam
case mist.stream(req) {
  Ok(consume) -> {
    case read_stream(consume, <<>>) {
      Ok(body) ->
        response.new(200)
        |> response.set_body(mist.Bytes(bytes_tree.from_bit_array(body)))
      Error(_) ->
        response.new(500) |> response.set_body(mist.Bytes(bytes_tree.new()))
    }
  }
  Error(_) ->
    response.new(400) |> response.set_body(mist.Bytes(bytes_tree.new()))
}

fn read_stream(consume, acc: BitArray) -> Result(BitArray, ReadError) {
  case consume(4096) {
    Ok(mist.Chunk(data, next)) -> read_stream(next, <<acc:bits, data:bits>>)
    Ok(mist.Done) -> Ok(acc)
    Error(e) -> Error(e)
  }
}
```

## Response Types

### Standard Response (Bytes)

```gleam
response.new(200)
|> response.set_header("content-type", "application/json")
|> response.set_body(mist.Bytes(bytes_tree.from_string("{\"ok\":true}")))
```

### Chunked Streaming Response

```gleam
import gleam/yielder

let chunks =
  yielder.from_list([
    bytes_tree.from_string("chunk 1\n"),
    bytes_tree.from_string("chunk 2\n"),
    bytes_tree.from_string("chunk 3\n"),
  ])

response.new(200)
|> response.set_body(mist.Chunked(chunks))
```

### File Response (Efficient sendfile)

```gleam
import gleam/option

case mist.send_file("/path/to/file.pdf", offset: 0, limit: option.None) {
  Ok(file_body) ->
    response.new(200)
    |> response.set_header("content-type", "application/pdf")
    |> response.set_body(file_body)
  Error(mist.NoEntry) ->
    response.new(404) |> response.set_body(mist.Bytes(bytes_tree.new()))
  Error(_) ->
    response.new(500) |> response.set_body(mist.Bytes(bytes_tree.new()))
}
```

`send_file` uses Erlang's `sendfile` — the file is sent directly from disk
without loading into memory.

### Partial File (Range Requests)

```gleam
// Serve bytes 1000-1999 of a file
mist.send_file("/path/to/file.mp4", offset: 1000, limit: option.Some(1000))
```

## Client Info

```gleam
case mist.get_client_info(req.body) {
  Ok(info) -> {
    let ip = mist.ip_address_to_string(info.ip_address)
    let port = info.port
    // ...
  }
  Error(Nil) -> // info unavailable
}
```

## WebSockets

### Upgrade to WebSocket

```gleam
pub type WsState {
  WsState(user_id: String)
}

fn handle_ws(req: request.Request(mist.Connection)) {
  mist.websocket(
    request: req,
    handler: fn(state, message, conn) {
      case message {
        mist.Text(text) -> {
          let assert Ok(_) = mist.send_text_frame(conn, "echo: " <> text)
          mist.continue(state)
        }
        mist.Binary(data) -> {
          let assert Ok(_) = mist.send_binary_frame(conn, data)
          mist.continue(state)
        }
        mist.Closed | mist.Shutdown -> mist.stop()
        mist.Custom(_msg) -> mist.continue(state)
      }
    },
    on_init: fn(_conn) {
      #(WsState(user_id: "anonymous"), option.None)
    },
    on_close: fn(_state) { Nil },
  )
}
```

### WebSocket Messages

```gleam
pub type WebsocketMessage(custom) {
  Text(String)       // text frame from client
  Binary(BitArray)   // binary frame from client
  Closed             // client closed connection
  Shutdown           // server shutting down
  Custom(custom)     // OTP message via selector
}
```

### Sending Frames

```gleam
mist.send_text_frame(conn, "hello")      // -> Result(Nil, SocketReason)
mist.send_binary_frame(conn, <<1, 2>>)   // -> Result(Nil, SocketReason)
```

### Receiving OTP Messages in WebSocket

```gleam
pub type WsMsg {
  Broadcast(String)
}

mist.websocket(
  request: req,
  handler: fn(state, message, conn) {
    case message {
      mist.Custom(Broadcast(text)) -> {
        let assert Ok(_) = mist.send_text_frame(conn, text)
        mist.continue(state)
      }
      mist.Text(_) -> mist.continue(state)
      mist.Closed | mist.Shutdown -> mist.stop()
      _ -> mist.continue(state)
    }
  },
  on_init: fn(_conn) {
    let subj = process.new_subject()
    let selector =
      process.new_selector()
      |> process.selecting(subj, fn(msg) { msg })
    // Store subj somewhere so other processes can send to it
    #(State(subject: subj), option.Some(selector))
  },
  on_close: fn(_state) { Nil },
)
```

### Dynamic Selector Updates

```gleam
// Change which OTP messages the handler listens for
mist.continue(new_state)
|> mist.with_selector(new_selector)
```

## Server-Sent Events (SSE)

```gleam
import gleam/otp/actor
import gleam/string_tree

fn handle_sse(req: request.Request(mist.Connection)) {
  mist.server_sent_events(
    request: req,
    initial_response: response.new(200)
      |> response.set_header("x-custom", "value"),
    init: fn(_subject) {
      // Set up periodic timer or subscribe to events
      actor.initialised(0)  // initial state: counter
    },
    loop: fn(state, _message, conn) {
      let event =
        mist.event(string_tree.from_string("count: " <> int.to_string(state)))
        |> mist.event_name("counter")
        |> mist.event_id(int.to_string(state))

      case mist.send_event(conn, event) {
        Ok(Nil) -> actor.continue(state + 1)
        Error(Nil) -> actor.stop(process.Normal)
      }
    },
  )
}
```

### SSE Event Builder

```gleam
mist.event(string_tree.from_string("data"))   // create event
|> mist.event_name("update")                   // event: update
|> mist.event_id("42")                         // id: 42
|> mist.event_retry(5000)                      // retry: 5000 (ms)
```

### Sending Events

```gleam
mist.send_event(conn, event)  // -> Result(Nil, Nil)
```

## Control Flow (WebSocket & SSE)

```gleam
mist.continue(state)                    // keep running with new state
mist.stop()                             // clean shutdown
mist.stop_abnormal("reason")            // abnormal shutdown with reason

mist.continue(state)
|> mist.with_selector(new_selector)     // update OTP message selector
```

## Integration with wisp

The standard pattern uses `wisp_mist.handler` to adapt a wisp handler:

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
```

`wisp_mist.handler` converts:
- `fn(wisp.Request) -> wisp.Response`
- into `fn(Request(mist.Connection)) -> Response(mist.ResponseData)`

## Complete Example: HTTP + WebSocket Server

```gleam
import gleam/bytes_tree
import gleam/erlang/process
import gleam/http.{Get}
import gleam/http/request
import gleam/http/response
import gleam/option
import mist

pub fn main() {
  let assert Ok(_) =
    mist.new(router)
    |> mist.port(4000)
    |> mist.start

  process.sleep_forever()
}

fn router(
  req: request.Request(mist.Connection),
) -> response.Response(mist.ResponseData) {
  case request.path_segments(req) {
    ["ws"] -> handle_websocket(req)
    ["health"] ->
      response.new(200)
      |> response.set_body(mist.Bytes(bytes_tree.from_string("ok")))
    ["file", ..path] -> serve_file(req, path)
    _ ->
      response.new(404)
      |> response.set_body(mist.Bytes(bytes_tree.from_string("Not found")))
  }
}

fn handle_websocket(req) {
  mist.websocket(
    request: req,
    handler: fn(state, msg, conn) {
      case msg {
        mist.Text(text) -> {
          let assert Ok(_) = mist.send_text_frame(conn, "echo: " <> text)
          mist.continue(state)
        }
        mist.Closed | mist.Shutdown -> mist.stop()
        _ -> mist.continue(state)
      }
    },
    on_init: fn(_conn) { #(Nil, option.None) },
    on_close: fn(_state) { Nil },
  )
}

fn serve_file(req, path_segments) {
  let path = "/var/www/" <> string.join(path_segments, "/")
  case mist.send_file(path, offset: 0, limit: option.None) {
    Ok(body) ->
      response.new(200)
      |> response.set_body(body)
    Error(_) ->
      response.new(404)
      |> response.set_body(mist.Bytes(bytes_tree.new()))
  }
}
```

## Best Practices

1. **Use wisp for web apps** — mist is the HTTP server, wisp provides the
   application framework (routing, middleware, body parsing, cookies, etc.)
2. **Always set a body size limit** — pass a reasonable `max_body_limit` to
   `read_body` to prevent denial-of-service
3. **Use `send_file` for static files** — it uses `sendfile` for zero-copy
   transfer, much more efficient than reading into memory
4. **Use `Chunked` for streaming** — `Yielder(BytesTree)` produces chunks
   lazily, keeping memory usage constant
5. **Handle `Closed` and `Shutdown`** in WebSocket handlers — always match
   these to clean up resources
6. **Use `supervised` in production** — integrate mist into your OTP
   supervision tree for automatic restarts
7. **Use `after_start` with port 0** — when the OS assigns a port, the
   callback tells you which port was chosen
