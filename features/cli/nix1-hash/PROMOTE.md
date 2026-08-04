# Soak / promote — `nix1-hash` → stock name

## Doctrine

1. **Ship parallel:** `nix1-hash` only (never overwrite `nix-hash` on day one).
2. **Soak:** user-local alias or profile toggle; run oracle corpus for days/weeks.
3. **Promote (optional):** only after differential oracle stays green vs pinned nixpkgs `nix-hash`.

## Soak (safe)

```fish
alias nix-hash=nix1-hash
```

or shell-agnostic:

```bash
nix-hash() { command nix1-hash "$@"; }
```

Keep stock binary available as `command nix-hash` / `\\nix-hash`.

## Promote (gated)

Do **not** enable until:

- `cargo test -p nix1` oracle suite green
- Live corpus script vs stock `nix-hash` green on this host
- No known flag/stdout/exit deltas

When promoting, add a feature option (future leaf) that installs a `nix-hash`
symlink to `nix1-hash` **and** keeps `nix-hash.stock` → nixpkgs if rollback needed.

This file is the gate checklist; symlink install is intentionally not automated yet.
