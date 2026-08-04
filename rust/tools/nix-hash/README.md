# nix-hash

**1:1** Rust reimplementation of stock **`nix-hash`**.

## Status

| Binary | Stock twin | Status |
|--------|------------|--------|
| `nix-hash` | classic `nix-hash` | Parity for hash / encodings / convert / truncate (oracle vs stock) |

## Usage

```bash
nix-hash --type sha256 --base32 path
nix-hash --flat --type md5 file
nix-hash --to-sri --type sha256 "$hex"
```

## Host install

`features/cli/nix-hash` puts this binary on PATH as `nix-hash`.

See `features/cli/nix-hash/PROMOTE.md` for rollback notes.

## Non-goals

- Replacing `nix` meta-CLI / daemon / evaluator / `nixos-rebuild`
