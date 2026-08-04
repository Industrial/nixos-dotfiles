# nix1

OS-facing **1:1** reimplementations of stock Nix CLIs, starting with **`nix1-hash`** ≡ `nix-hash`.

## Status

| Binary | Stock twin | Status |
|--------|------------|--------|
| `nix1-hash` | `nix-hash` | Parity for hash / encodings / convert / truncate (oracle vs stock) |

## Usage

```bash
nix1-hash --type sha256 --base32 path
nix1-hash --flat --type md5 file
nix1-hash --to-sri --type sha256 "$hex"
```

## Rollout

See `features/cli/nix1-hash/PROMOTE.md`.

1. Use `nix1-hash` beside stock `nix-hash`
2. Soak: `alias nix-hash=nix1-hash`
3. Promote only after oracle stays green

## Non-goals

- Replacing `nix` meta-CLI / daemon / evaluator / `nixos-rebuild` in this crate's first mission
