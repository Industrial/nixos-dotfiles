# ADR-0010: fleet inventory and feature catalog are typed Voltaic data, NixOS reads generated JSON

**Status:** Accepted
**Date:** 2026-11-27
**Issue:** #417, stage S2 (typed fleet data)

## Context

`common/fleet.nix` (hosts, roles, builders, operator keys, tailnet addresses, cache keys and,
since #421, the compartment trust facts) and `features/catalog.nix` (every switchable
feature) were untyped Nix attrsets and lists. A misspelt role, a builder missing from
`builderOrder`, a duplicate tailnet address or a malformed operator key showed up at eval time
as a wrong value, or not at all. Stage S2 of #417 makes this data Voltaic types, and NixOS
consumes generated JSON. The eval has to stay identical.

## Decision

1. **The source of truth is a typed Voltaic module**, not a separate data file. It lives in
   the `vfleet` crate (`rust/tools/vfleet`):
   - `src/model.vlt` holds the types. `HostName`, `Role`, `SystemFeature`, `TrustTier`,
     `CpuVendor` and `Category` are closed sum types, each with one exhaustive `*_name`
     function that gives the string NixOS sees. `Host`, `BuilderSpec`, `Cpu`, `Ports`,
     `Fleet` and `Feature` are records.
   - `src/inventory.vlt` holds the hosts. It carries the per-field and per-host comments that
     used to be in `fleet.nix`.
   - `src/catalog.vlt` holds the catalog entries, in import order.

   A data file (TOML/JSON parsed at run time) was rejected. It could only be checked at run
   time, while a Voltaic module gets compile-time checks for free.

2. **What is checked at compile time:** roles, builder features, trust tiers, CPU vendors and
   catalog categories come from closed sets. The three host orders can only name declared
   hosts. Every host record has every field. Tailnet addresses are `Ipv4Addr::new` with u8
   octets, and ports are u16.

3. **What is checked at run time** (`src/check.vlt`, run by every vfleet command and by its
   tests on the real data):
   - Every declared host has exactly one record, and `order` names each host once.
   - Builders exist: a builder spec appears exactly when the host has the `builder` role, and
     `builderOrder` is exactly the builder-role hosts.
   - `nfsClientOrder` is exactly the nfs-client hosts. Each of them has a tailnet address,
     and none is a work host.
   - Tailnet addresses are unique and inside 100.64.0.0/10. Fleet ports are unique and
     non-zero.
   - Each operatorKey is `ssh-ed25519 <51-byte blob> tom@<host>` and no two hosts share one.
     Each cacheKey is `<host>-vcache-N:<32 bytes>` and sits only on a builder with an address.
   - The trust facts agree: hw-attested iff tpm2, SEV-SNP only on AMD, TDX only on Intel, and
     an attestationRoot only with a TPM2.
   - Catalog entries are unique plain relative paths, and no two of them map to one option.

4. **The JSON is checked in** at `common/fleet.json` and `features/catalog.json`.
   `common/fleet.nix` keeps every derived helper (withRole, builders, binaryCaches,
   pushesToCacheIn, ...) and reads its data with `builtins.fromJSON`. `features/catalog.nix`
   maps the JSON paths back to Nix paths (`./. + "/${p}"`). So no consumer changes, and an
   eval needs no Rust build. The JSON keeps the old field names. Optional fields are left out
   when absent (`h ? tailscaleIp` and `online or true` behave as before), and the
   attrsets equal the old ones exactly.

5. **A drift gate:** vfleet's cargo test compares the generated JSON with the checked-in
   files byte for byte. It runs in CI (`bin/ci/cargo-standalone test vfleet`, found
   automatically by `--list`) and inside the package's sandbox build, whose source carries
   the two JSON files. `bin/fleet-data` regenerates both files and `bin/fleet-data --check`
   runs the same comparison. The JSON is excluded from treefmt: its form is vfleet's (sorted
   keys, serde_json pretty).

6. **The oracle (#417):** with `configurationRevision` pinned to a constant, the toplevel
   `.drv` of drakkar, huginn, mimir and muninn is byte-identical before and after the change.
   Separately, `rust/tools/vfleet/default.assay.nix` asserts that `fleet.hosts`, the orders,
   `cachePort` and the catalog paths equal the JSON.

## Consequences

- Changing a host or adding a feature means editing a `.vlt` file, running `bin/fleet-data`
  (about 1.4 s incremental) and committing both files. `AGENTS.md`, the headers of
  `fleet.nix` and `catalog.nix`, and `inventory.vlt` all say so.
- The derived helpers are still Nix. Moving them into Voltaic, so features consume typed
  values rather than recomputing them, is later work (S3+).
- Ports: the fleet declares a single port today, vcache's 5100. The uniqueness check runs
  over `Ports`, so a second service has to be added as a field there.

## Voltaic 0.3.0 friction met (for the S1b feature check, not duplicated here)

- A multi-line record literal must open its `{` on the constructor's line (`Host {`). A list
  must open its `([` on the same line. A leading-brace or leading-bracket continuation line
  is a parse error.
- `for (a, b) in xs` is a parse error, because `for` takes a name only. Use `.0` / `.1`.
- No turbofish in an expression (`Vec::<String>::new ()`). Bind with an ascription instead.
- An interpolated string cannot hold a macro call with escaped quotes, such as
  `"#{env!(\"X\")}"`. Bind it first.
- A `|> .unwrap_or false && …` pipeline binds the `&&` into the method arguments. It needs
  parentheses.
- `if x.field is Some v` on a borrowed record moves the field out. Use
  `x.field.as_ref () is Some v`.
- Error data `errors E` prints through `Debug` under `id_effect_cli::run_main`
  (`error: Drift("…")`), not through its declared message.
- There are no sum-type iteration or derived "all variants" lists. `all_hosts` is written by
  hand and checked at run time against the records.
