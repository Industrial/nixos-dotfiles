# Browser APIs with plinth

plinth provides typed Gleam bindings to browser and Node.js APIs via FFI, so you don't need to write your own. Reach for plinth before writing custom FFI for any standard web platform API.

## Module Inventory

**DOM & Elements:**
- `document` — querySelector, createElement, get/set title, cookie access
- `element` — attributes, events, scroll, focus, bounding rect
- `shadow` — attach/query shadow DOM
- `dom_token_list` — CSS class manipulation (add, remove, toggle, contains)

**Window & Navigation:**
- `window` — alert, confirm, sizing, postMessage, requestAnimationFrame
- `location` — origin, pathname, hash, reload, assign

**Storage:**
- `storage` — localStorage/sessionStorage get/set/remove/clear

**Crypto:**
- `crypto` — random_uuid, get_random_values
- `crypto/subtle` — digest, sign, verify, encrypt, decrypt, key generation

**Communication:**
- `broadcast_channel` — cross-tab messaging
- `worker` — Web Worker creation and messaging
- `service_worker` — service worker registration

**Input & Files:**
- `clipboard` — read/write text
- `file` — read text/bytes from File objects, create object URLs
- `file_system` — File System Access API (showOpenFilePicker, etc.)
- `drag` — data_transfer, drag event files

**Media & UI:**
- `audio` — play audio elements
- `selection` / `range` — text selection and range manipulation

**Platform:**
- `geolocation` — current position, watch position
- `serial` — Serial Port API
- `credentials` / `public_key` — WebAuthn / passkeys

**JavaScript Utilities:**
- `console` — log, warn, error, debug
- `date` — Date object operations
- `global` — setTimeout, setInterval, clearTimeout, encodeURI, encodeURIComponent
- `big_int` — BigInt operations
- `compression_stream` / `decompression_stream` — Compression Streams API

**Node.js:**
- `fs` — file system operations
- `process` — process.env, argv, exit
- `child_process` — spawn child processes
- `stream` — readable/writable streams
- `readlines` — line-by-line file reading

## Usage Pattern

Use plinth inside Lustre effects via `effect.from`:

```gleam
import plinth/browser/storage

fn load_theme() -> effect.Effect(Msg) {
  effect.from(fn(dispatch) {
    case storage.local() {
      Ok(store) ->
        case storage.get_item(store, "theme") {
          Ok(theme) -> dispatch(ThemeLoaded(theme))
          Error(_) -> dispatch(ThemeLoaded("light"))
        }
      Error(_) -> dispatch(ThemeLoaded("light"))
    }
  })
}
```

## What plinth Does NOT Cover

`document.cookie` is absent from plinth. For cookies, write minimal FFI (2 functions for get/set) and use `gleam/http/cookie` for parsing and building cookie strings.

## When to Use plinth vs Custom FFI

Use plinth whenever a binding exists for the API you need. Write custom FFI only for APIs plinth doesn't cover (document.cookie, specific animation APIs like `element.animate()`, etc.). Check plinth's module list first before reaching for `@external`.
