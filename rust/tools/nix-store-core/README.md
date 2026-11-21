# nix-store-core

Nix store primitives for the Voltaic store tools in `rust/tools/`: store paths,
nix32, SHA-256 forms, NAR serialisation and hashing, narinfo, signatures,
`.drv` parsing, and read-only queries of the store database. Written in
Voltaic 0.2.1 (`src/*.vlt`, compiled by `build.rs`), with id_effect 0.13.0
for the one streaming face (`nar::stream`).

Everything here is a plain function over values, except the reads of the
filesystem (`nar`, `drv::read`) and of the database (`db`), which are
blocking calls. A tool that runs them inside an effect wraps them in
`suspend`, as vcache's `store` does.

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

## Tests

`cargo test` runs:

- unit tests in every module. `storepath`'s tests are vgc's, verbatim.
- `golden`: vectors from C++ Nix 2.31.4, stored in `tests/fixtures/`:
  - 60 store paths: `nix path-info --json`, `nix hash path` in SRI/base-16/nix32, and `nix-store -qR`.
  - 56 `.drv` files, with their ATerm text and `nix derivation show`.
  - a synthetic tree's `nix hash path`.

  The checks of hash conversion, fingerprints, cache.nixos.org signatures,
  narinfo round-trips and the ATerm parser need no store, so they run
  everywhere. The NAR hashes of real paths and the database's references and
  closures run over the fixture paths this machine has. Where it has none,
  such as the build sandbox, they pass vacuously.
- `conformance`: up to 400 random valid paths, NAR-hashed and compared with
  the database's narHash. This test skips where there is no database.

To regenerate the fixtures, from this directory run `tests/gen-fixtures.sh tests/fixtures`,
with `nix` and `jq` available (a few minutes; reads only).
`default.nix` packages the crate as its own test run.
