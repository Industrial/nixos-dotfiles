# plinth

Bindings to Node.js and browser platform APIs. Minimal abstraction; close to native APIs.

**Package:** [plinth on Hex](https://hex.pm/packages/plinth)  
**Docs:** [HexDocs](https://hexdocs.pm/plinth/)

## When to use

- Browser: DOM, storage, clipboard, crypto, file system, geolocation, etc.
- Node: file system, process, child processes, streams.

## Entrypoints (by area)

- **plinth/browser/** — `element`, `document`, `event`, `storage`, `clipboard`, `crypto/subtle`, `indexeddb/*`, `window`, `worker`, etc.
- **plinth/node/** — `fs`, `process`, `child_process`, `stream`, `readlines`.
- **plinth/javascript/** — `console`, `date`, `global`, `storage`, `big_int`, etc.

Use the module that matches the API you need (e.g. `plinth/browser/document`, `plinth/node/fs`). Docs list all modules; pick the one for your target (browser vs node) and the capability you need.
