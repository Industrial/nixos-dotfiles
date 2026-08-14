# Promote / rollback — `nix-hash` (Rust)

This feature installs our binary as **`nix-hash`**, replacing classic Nix CLI on PATH.

## Preconditions

- `cargo test -p nix-hash` oracle suite green
- tools_compat / nixpkgs caller soak green

## Rollback

If needed, temporarily prefer stock:

```bash
nix-hash.stock() { command -p nix-hash "$@" 2>/dev/null || "$(dirname "$(command -v nix)")/nix-hash" "$@"; }
```

Or disable `features/cli/nix-hash` in the host profile and rebuild.
