# Compat fixtures (nix-unit / `lib.runTests`)

These fixtures exercise the **compat loader** (`assay::compat`) that accepts the
familiar nix-unit / `lib.runTests` attribute shape:

```nix
{
  testName = {
    expr = <nix expression>;
    expected = <nix value or expression string>;
  };
}
```

## Files

| File | Purpose |
|------|---------|
| `suite.json` | Canonical JSON suite (≥6 cases). Used by `cargo test` without Nix. |
| `suite.nix` | Same cases as Nix values; `nix eval --impure --file suite.nix --json`. |
| `trim_identity.nix` | Single-case: string trim |
| `list_len.nix` | Single-case: `builtins.length` |
| `bool_and.nix` | Single-case: boolean `&&` |
| `attr_get.nix` | Single-case: attribute access |
| `list_concat.nix` | Single-case: list concatenation |

## Loading

```rust
use assay::load_compat_suite;

let suite = load_compat_suite(path)?;
for case in &suite.cases {
    let claim = assay::compat::to_claim(case);
    // CompatClaim::Eq { left_expr, right_expr }
}
```

- **`.json`**: parsed directly.
- **`.nix`**: `nix eval --impure --file <path> --json`, then parsed. If `nix` is
  unavailable, falls back to a sidecar `<stem>.json` (e.g. `suite.nix` → `suite.json`).

## Mapping to Assay claims

Each compat case maps to an equality claim: evaluate `expr` and `expected` in
isolation and compare normalized results (`CompatClaim::Eq`).
