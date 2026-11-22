# nix-store-core

Nix store primitives for the Voltaic store tools in `rust/tools/`: store paths,
nix32, SHA-256 forms, NAR serialisation and hashing, narinfo, signatures,
`.drv` parsing, and read-only queries of the store database. Written in
Voltaic 0.2.1 (`src/*.vlt`, compiled by `build.rs`), with id_effect 0.13.0
for the one streaming face (`nar::stream`).

Everything here is a plain function over values, except the reads of the
filesystem (`nar`, `drv::read`) and of the database (`db`), which are
blocking calls, and the daemon protocol client (`worker`), whose operations
are id_effect effects over tokio I/O. A tool that runs the blocking ones inside
an effect wraps them in `suspend`, as vcache's `store` does.

## Using it

nix-store-core is a standalone crate (own `Cargo.lock`, empty `[workspace]`).
Take it as a path dependency:

```toml
[dependencies]
nix-store-core = { path = "../nix-store-core" }
```

The package's source then has to hold both crates. Root the fileset at
`rust/tools` and point the build at your crate. `rust/tools/vcache/default.nix`
is the reference:

```nix
src = lib.fileset.toSource {
  root = ./..;
  fileset = lib.fileset.unions [
    ./Cargo.toml ./Cargo.lock ./build.rs ./src
    ../nix-store-core/Cargo.toml ../nix-store-core/build.rs ../nix-store-core/src
  ];
};
cargoRoot = "<crate>";
buildAndTestSubdir = "<crate>";
cargoLock.lockFile = ./Cargo.lock;
```

In Voltaic, import what you use: `import nix_store_core::storepath::{valid_base, store_base}`.
Pin `id_effect = "=0.13.0"` if you use it too, because types from two id_effect
versions do not unify.

## API

Signatures are written in Voltaic (`a -> b -> c` is `fn(a, b) -> c`).

### `storepath`: store paths, as Nix 2.35.6 `path.cc` accepts them

This is vgc's module, unchanged, with its tests. All functions are pure and exact.

| Item | Meaning |
|---|---|
| `STORE_DIR : &str` | `/nix/store` |
| `STORE_PREFIX : &str` | `/nix/store/` |
| `HASH_LEN : usize` | 32, the length of a hash part |
| `MAX_NAME_LEN : usize` | 211 (`StorePath::MaxPathLen`) |
| `nix32_char : char -> bool` | a character of Nix's base-32 alphabet |
| `name_char : char -> bool` | a character allowed in the name part |
| `valid_name : &str -> bool` | `checkName`: non-empty, ≤ 211, legal characters, first component not `.`/`..` |
| `valid_base : &str -> bool` | whether `<hash>-<name>` (no directory) is a store path |
| `hash_part : &str -> &str` | the hash part of a base name already known to be valid |
| `is_derivation : &str -> bool` | the name ends in `.drv` |
| `in_store : &str -> bool` | `isInStore`: strictly under `STORE_DIR` |
| `store_base : &str -> Option<&str>` | `toStorePath(..).first`: the store path base of any path inside the store |
| `full : &str -> String` | `STORE_PREFIX` + base name |
| `is_hash_part : &str -> bool` | exactly `HASH_LEN` nix32 characters |
| `base_name : &str -> &str` | the text after the last `/` |
| `hash_part_of : &str -> Option<&str>` | the hash part of a full path in *any* store directory |

### `nixbase32`: Nix's base-32 encoding, and base-16

| Item | Meaning |
|---|---|
| `ALPHABET : &[u8]` | `0123456789abcdfghijklmnpqrsvwxyz` |
| `encoded_len : usize -> usize` | characters for `n` bytes |
| `encode : &[u8] -> String` | libutil's `printHash32` |
| `decode : &str -> Option<Vec<u8>>` | `parseHash32`. None for a bad character, a bad length or stray high bits |
| `is_nixbase32 : &str -> bool` | every character is in the alphabet |
| `encode_hex : &[u8] -> String` / `decode_hex : &str -> Option<Vec<u8>>` | base-16 |
| `narinfo_hash : &str -> Option<String>` | `sha256:<base16>` (database form) to `sha256:<nix32>` (narinfo form). Already-nix32 input passes through |

### `hash`: SHA-256 and the forms Nix prints

| Item | Meaning |
|---|---|
| `Sha256 { bytes: [u8; 32] }` | a digest: `Copy`, `Eq`, `Ord`, `Hash` |
| `digest : &[u8] -> Sha256` | SHA-256 of bytes |
| `from_bytes : &[u8] -> Option<Sha256>` | exactly 32 raw bytes |
| `to_base16`, `to_nix32`, `to_base64`, `to_sri : &Sha256 -> String` | bare forms. SRI is `sha256-<base64>` |
| `typed_base16`, `typed_nix32 : &Sha256 -> String` | `sha256:<base16>` / `sha256:<nix32>` |
| `parse : &str -> Option<Sha256>` | any of SRI, `sha256:<b16/nix32/b64>`, or a bare 64/52/44-character digest. Other algorithms are refused |

### `nar`: the NAR serialisation, as a pull cursor

Memory stays at one chunk (about 256 KiB) whatever the path's size, and
nothing is read before the consumer pulls. This is what keeps vcache at
4.4 MB RSS while it serves a 526 MB NAR.

| Item | Meaning |
|---|---|
| `MAGIC`, `CHUNK` | `nix-archive-1`. The chunk size is 262144 |
| `cursor : &Path -> NarCursor` | the archive of a path, nothing read yet |
| `next_chunk : &mut NarCursor -> io::Result<Option<Bytes>>` | the next chunk, or None at the end |
| `stream : PathBuf -> Stream<Bytes, io::Error, HNil>` | the cursor as an id_effect stream (`Stream::unfold_effect`) |
| `dump : &mut impl Write -> &Path -> io::Result<()>` | the whole archive into a writer |
| `NarDigest { hash: Sha256, size: u64 }` | narHash and narSize |
| `nar_hash : &Path -> io::Result<NarDigest>` | the NAR hash and size of a path (`nix hash path`, `nix path-info`'s narHash and narSize) |
| `nar_hash_nix32 : &Path -> io::Result<String>` | the NAR hash as bare nix32 (`nix-hash --type sha256 --base32`) |
| `padding`, `push_bytes` | the wire-format string encoding |

Symlinks are not followed. Directory entries are ordered by byte order of
their names. The only mode bit recorded is the owner-execute bit.

### `narinfo`: what a binary cache serves per path

| Item | Meaning |
|---|---|
| `NarInfo { store_path, nar_hash, nar_size: u64, references: Vec<String>, deriver: Option<String>, sigs: Vec<String>, ca: Option<String> }` | `nar_hash` is `sha256:<nix32>`. References and the deriver are full paths |
| `fingerprint : &NarInfo -> String` | `1;<path>;<nar hash>;<nar size>;<refs joined by ,>`, what a signature covers |
| `NarInfoFile { info, url, compression, file_hash: Option<String>, file_size: Option<u64> }` | a narinfo file as served |
| `parse : &str -> Result<NarInfoFile, String>` | StorePath, URL, NarHash and NarSize are required. Compression defaults to `bzip2`. Unknown keys are ignored. `Deriver: unknown-deriver` parses as none |
| `render_file : &NarInfoFile -> String` | the text, in libstore's field order |
| `render : &NarInfo -> String` | vcache's form: `URL: nar/<hash part>.nar`, `Compression: none` |
| `nar_url : &NarInfo -> String`, `cache_info : &str -> i64 -> String` | vcache's URL and `/nix-cache-info` |

### `signing`: ed25519 in Nix's key format

| Item | Meaning |
|---|---|
| `SecretKey { name, .. }: Clone` | parsed from `<name>:<base64(seed ‖ public)>` (`nix key generate-secret`) |
| `PublicKey { name, .. }: Clone + Eq` | parsed from `<name>:<base64(32 bytes)>` (`trusted-public-keys`) |
| `parse_secret_key`, `parse_public_key : &str -> Result<_, String>` | surrounding whitespace is ignored |
| `sign : &SecretKey -> &str -> String` | the `Sig:` value (`<name>:<base64>`) for a fingerprint |
| `public_of : &SecretKey -> PublicKey`, `public_key : &SecretKey -> String`, `render_public_key : &PublicKey -> String` | the public half of a key |
| `verify : &PublicKey -> &str -> &str -> bool` | whether the signature is this key's (same name) over this fingerprint |
| `valid_signatures : &[PublicKey] -> &NarInfo -> usize` | libstore's `checkSignatures`: how many of the narinfo's sigs a trusted key made |

### `drv`: store derivations (ATerm)

| Item | Meaning |
|---|---|
| `Derivation { outputs: BTreeMap<String, Output>, input_drvs: BTreeMap<String, BTreeSet<String>>, input_srcs: BTreeSet<String>, system, builder, args: Vec<String>, env: BTreeMap<String, String> }` | the fields of `Derive(...)`. Paths are full |
| `Output { path, hash_algo, hash }` | `hash_algo` is `sha256` (flat), `r:sha256` (recursive) or `text:sha256`, with a base-16 `hash`, for fixed outputs. Both are empty for input-addressed outputs. A content-addressed output has an empty `path` |
| `parse : &str -> Result<Derivation, String>` | `parseDerivation`. The dynamic-derivation form `DrvWithVersion` is refused |
| `read : &Path -> Result<Derivation, String>` | read the file, then parse it |
| `is_fixed_output : &Derivation -> bool`, `output_paths : &Derivation -> BTreeMap<String, String>` | conveniences |

### `db`: the store database, read-only

These are blocking reads over a `rusqlite::Connection` (rusqlite 0.37, bundled).
A connection is `Send` but not `Sync`, so use one per fiber or thread, or pool
them.

| Item | Meaning |
|---|---|
| `DEFAULT_DB : &str` | `/nix/var/nix/db/db.sqlite` |
| `open : &str -> rusqlite::Result<Connection>` | read-only and no-mutex. Works without root or the daemon |
| `path_info : &Connection -> &str -> rusqlite::Result<Option<NarInfo>>` | a valid path's info by full path (`nix path-info --json`, hash in nix32) |
| `lookup : &Connection -> &str -> &str -> rusqlite::Result<Option<NarInfo>>` | the same by store dir and hash part (a range scan of one row) |
| `is_valid : &Connection -> &str -> rusqlite::Result<bool>` | the path is in ValidPaths |
| `references : &Connection -> &str -> rusqlite::Result<Option<Vec<String>>>` | direct references, sorted (`nix-store -q --references`) |
| `closure : &Connection -> &str -> rusqlite::Result<Option<Vec<String>>>` | the closure including the path, sorted (`nix-store -qR`). Uses one recursive SQL query |
| `closure_of_all : &Connection -> &[String] -> rusqlite::Result<BTreeSet<String>>` | the union of several closures. Paths that are not valid are skipped |

None means "not a valid path". GC roots and the `DerivationOutputs` walk stay in vgc.

### `testdb`: store databases for tests (`test-support` feature)

Built for this crate's own tests, and for a consumer's with the
`test-support` feature, taken as a dev-dependency feature so the consumer's
build keeps the plain API (`Cargo.lock` does not change):

```toml
[dev-dependencies]
nix-store-core = { path = "../nix-store-core", features = ["test-support"] }
```

| Item | Meaning |
|---|---|
| `SCHEMA : &str` | libstore's `schema.sql`: ValidPaths, Refs with IndexReferrer and IndexReference, DerivationOutputs |
| `schema_db : &str -> Connection` | an empty store database at a file path or `:memory:`; the caller inserts rows with SQL |
| `memory_db : Vec<(&str, &str, Vec<&str>)> -> Connection` | in memory, with (path, base-16 hash, references) rows, each at time 0 with narSize 8 |

They panic on failure: they are fixtures.

### `generations`: profile generations and `--delete-older-than`

vgc's module (`rust/tools/vgc/src/generations.vlt`), lifted unchanged with its
tests, so vgen's prune and vgc's flag apply one rule. Copied from Nix 2.35.6
`profiles.cc`. All functions are pure: the caller reads the directory and the
link mtimes.

| Item | Meaning |
|---|---|
| `Generation { number: u64, mtime: i64 }` | one `<profile>-<N>-link` and its link time |
| `parse_generation : &str -> &str -> Option<u64>` | `parseName`: the number of `<profile>-<N>-link` (text after `-link` ignored) |
| `cutoff_of : &str -> i64 -> Result<i64, String>` | `parseOlderThanTimeSpec`: `Nd` (N ≥ 1) as a cutoff in epoch seconds, given now |
| `doomed : &[Generation] -> Option<u64> -> i64 -> Option<Vec<u64>>` | `deleteGenerationsOlderThan`: what goes, ascending. The newest generation older than the cutoff and the current one stay. None when creation times are not monotonic below the kept one, where Nix aborts: remove nothing |
| `all_but : &[Generation] -> Option<u64> -> Vec<u64>` | `deleteOldGenerations` (`nix-collect-garbage -d`): every generation but the current one, ascending |

### `worker`: the nix-daemon worker protocol

What `nix` speaks to nix-daemon over `/nix/var/nix/daemon-socket/socket`, and
over `ssh host nix-daemon --stdio`. The client offers protocol 1.37
(`CLIENT_VERSION = 293`) and accepts any daemon from 1.24 (`MIN_VERSION`); a
newer daemon negotiates down. The server handshake and
the decoders also handle 1.38's feature exchange.

Three layers, each usable on its own:

**Pure grammar.** Decoders `take_* : &[u8] -> usize -> Result<(T, usize), Short>`
read one value at a position and return where the next starts; `Short::More`
means the buffer ends early, `Short::Bad` that it is not the protocol (lengths
are capped at `MAX_STRING` and `MAX_LIST`, so garbage is refused before it is
allocated). Encoders `put_* : &mut Vec<u8> -> .. -> ()` write into a buffer.

| Item | Meaning |
|---|---|
| `take_u64`, `take_bool`, `take_bytes`, `take_string`, `take_strings`, `take_optional` | u64 LE; padded strings (lossy UTF-8); string lists; `""` as none |
| `put_u64`, `put_bool`, `put_bytes`, `put_str`, `put_strings`, `put_optional`, `put_frame` | the same, written. `put_frame` is one frame of a framed upload (unpadded; an empty frame ends it) |
| `WORKER_MAGIC_1`, `WORKER_MAGIC_2`, `STDERR_*`, `minor`, `major` | the constants and version halves |
| `Op` (44 variants), `ALL_OPS`, `op_code : Op -> u64`, `op_of_code : u64 -> Option<Op>`, `op_name : Op -> String` | every libstore op code, obsolete ones included |
| `StderrMsg = LogNext String \| DataRead u64 \| DataWrite Vec<u8> \| Last \| Failed DaemonFailure \| StartActivity Activity \| StopActivity u64 \| ActivityResult u64 u64 (Vec<Field>)` | one message of the stderr stream |
| `take_stderr : u64 -> &[u8] -> usize -> ..`, `put_stderr : &mut Vec<u8> -> u64 -> &StderrMsg -> ()` | by protocol version (the error format changed at 1.26) |
| `DaemonFailure { message, level, traces }`, `Activity { id, level, kind, text, fields, parent }`, `Field = Int u64 \| Text String` | |
| `Request { code, op: Option<Op>, paths }`, `take_request : u64 -> &[u8] -> usize -> ..` | the op and the store paths a request starts with, for logging (it does not find the request's end) |
| `PathInfo { path, deriver, nar_hash: Sha256, references, registration_time, nar_size, ultimate, sigs, ca }` | `take_path_info`, `take_path_info_reply`, `put_path_info` |
| `NarScan`, `nar_scan ()`, `nar_step : &mut NarScan -> &[u8] -> usize -> Result<usize, Short>` | finds the end of a NAR on the wire (NarFromPath's reply is an unframed NAR), passing file contents in pieces |

**Buffered connection.** `Conn` holds a boxed `AsyncRead` and `AsyncWrite`
(`conn_of : Reader -> Writer -> Conn`), a read buffer and the negotiated
`version`. Async functions over it:

| Item | Meaning |
|---|---|
| `next : &mut Conn -> F -> Result<T, WorkerError>` | run a decoder, reading as much as it needs |
| `send : &mut Conn -> &[u8] -> Result<(), WorkerError>` | write and flush |
| `pending : &Conn -> &[u8]` | bytes read but not yet decoded (hand them on before switching to a raw relay) |
| `client_handshake : &mut Conn -> u64 -> ..`, `server_handshake : &mut Conn -> &ServerHello -> ..` | both sides; `ServerHello { version, nix_version, trusted, features }` |
| `process_stderr : &mut Conn -> Result<(), WorkerError>` | up to `Last`; `Failed` becomes `WorkerError::Remote` |
| `relay_stderr : &mut Conn -> &mut Conn -> Result<StderrEnd, WorkerError>` | relay one op's stderr stream from the daemon side to the client side, answering `DataRead` from the client; `StderrEnd = Done \| Errored DaemonFailure` |
| `copy_nar : &mut Conn -> FnMut(&[u8]) -> ..` | pass the NAR after NarFromPath's `Last` to a sink, exactly as sent |
| `is_valid_path_on`, `query_valid_paths_on`, `query_path_info_on`, `query_path_from_hash_part_on`, `nar_from_path_on`, `nar_hash_from_path_on`, `add_to_store_nar_on`, `add_to_store_nar_from_on`, `add_temp_root_on`, `add_signatures_on` | the ops below, on a `&mut Conn` |

A proxy forwards an op by sending what it read (`take_request` names it,
`pending` and the raw bytes carry the rest) and relaying the stderr stream
with `relay_stderr`, or, as vdaemon-proxy does, by relaying both directions
byte for byte and following the conversation with `take_request` and
`take_stderr`. After an I/O or protocol error the connection is out of step,
and every later use fails with `Broken`.

**`Daemon`, the connection as an id_effect resource.** `Daemon` is a
`Clone` handle (`Arc<tokio::sync::Mutex<Conn>>`); ops on it take turns. Every
op is an `Effect<_, WorkerError, HNil>`.

| Item | Meaning |
|---|---|
| `DEFAULT_SOCKET : &str` | `/nix/var/nix/daemon-socket/socket` |
| `connect : String -> Effect<Daemon, ..>` | connect to a socket path and shake hands; release with `close` |
| `open : S -> Effect<Daemon, ..>` | over any `AsyncRead + AsyncWrite + Send + Unpin + 'static` stream |
| `open_halves : R -> W -> Effect<Daemon, ..>` | over separate halves: a child's stdout and stdin (`ssh host nix-daemon --stdio`) |
| `close : Daemon -> Effect<(), Never, HNil>` | shut the write side; later ops fail with `Broken` |
| `with_daemon : String -> (Daemon -> Effect<A, WorkerError, HNil>) -> Effect<A, ..>` | connect, use, close however the use ends (`acquire_use_release`) |
| `scoped : &Scope -> String -> Effect<Daemon, ..>` | connect, with the close registered on the scope |
| `hello : &Daemon -> Effect<Hello, ..>` | `Hello { version, daemon_nix_version, trusted }` from the handshake |
| `is_valid_path : &Daemon -> String -> Effect<bool, ..>` | IsValidPath |
| `query_valid_paths : &Daemon -> Vec<String> -> bool -> Effect<Vec<String>, ..>` | QueryValidPaths; the flag asks the daemon to substitute missing paths first |
| `query_path_info : &Daemon -> String -> Effect<Option<PathInfo>, ..>` | QueryPathInfo; None when not valid |
| `query_path_from_hash_part : &Daemon -> String -> Effect<Option<String>, ..>` | QueryPathFromHashPart |
| `nar_from_path : &Daemon -> String -> Effect<Vec<u8>, ..>` | NarFromPath, the whole NAR in memory |
| `nar_hash_from_path : &Daemon -> String -> Effect<NarDigest, ..>` | NarFromPath, hashed as it streams (one buffer) |
| `add_to_store_nar : &Daemon -> PathInfo -> Vec<u8> -> bool -> bool -> Effect<(), ..>` | AddToStoreNar from a NAR in memory, framed; the flags are `repair`, `dont_check_sigs` |
| `add_to_store_nar_from : &Daemon -> PathInfo -> PathBuf -> bool -> bool -> Effect<(), ..>` | AddToStoreNar from the NAR of a local path, archived and framed chunk by chunk |
| `add_temp_root : &Daemon -> String -> Effect<(), ..>` | AddTempRoot: the path lives while the connection does |
| `add_signatures : &Daemon -> String -> Vec<String> -> Effect<(), ..>` | AddSignatures |

`WorkerError = Io io::Error | Connect String | Protocol String | Remote String | Broken String`.
`Remote` is the daemon's own STDERR_ERROR (the connection stays usable).

**Run it inside tokio.** `connect` creates a tokio `UnixStream`, which needs
the tokio runtime's context. `Runtime::block_on` and id_effect_cli's
`run_main` poll their root fiber on the calling thread, outside that context,
so run the effect on a fiber of the executor: `rt.fork(eff)` then
`rt.block_on(handle.join())`, or fork the program inside `run_main` as
vcache's `supervised` does. `open` / `open_halves` over streams made inside
the runtime (such as `tokio::process` pipes) work either way.

## Tests

`cargo test` runs:

- unit tests in every module. `storepath`'s and `generations`' tests are vgc's, verbatim.
- `golden`: vectors from C++ Nix 2.31.4, stored in `tests/fixtures/`:
  - 60 store paths: `nix path-info --json`, `nix hash path` in SRI/base-16/nix32, and `nix-store -qR`.
  - 56 `.drv` files, with their ATerm text and `nix derivation show`.
  - a synthetic tree's `nix hash path`.

  The checks of hash conversion, fingerprints, cache.nixos.org signatures,
  narinfo round-trips and the ATerm parser need no store, so they run
  everywhere. The NAR hashes of real paths and the database's references and
  closures run over the fixture paths this machine has. Where it has none,
  such as the build sandbox, they pass vacuously.
- `worker`: the grammar's round-trips (every value, every stderr message in
  both error formats, every proper prefix is `More`), op codes, request
  scanning, the NAR scanner fed in 7-byte pieces, and the client against a
  scripted fake daemon over an in-memory pipe: both handshakes (1.37 and
  1.38's features), log traffic, a `Remote` error that leaves the connection
  usable, AddToStoreNar's frames and NarFromPath's NAR.
- `worker_live`: the client against this machine's daemon. IsValidPath and
  QueryValidPaths, QueryPathInfo against `nix path-info --json` for ten paths
  (the current system's references), QueryPathFromHashPart, NarFromPath
  against `nix hash path`, AddTempRoot under `with_daemon`. They skip where
  there is no daemon socket or `nix`, such as the build sandbox.
- `conformance`: up to 400 random valid paths, NAR-hashed and compared with
  the database's narHash. This test skips where there is no database.

To regenerate the fixtures, from this directory run `tests/gen-fixtures.sh tests/fixtures`,
with `nix` and `jq` available (a few minutes; reads only).
`default.nix` packages the crate as its own test run.
