---
name: rust-devenv
description: >-
  Rust toolchain and dev environment on NixOS via devenv.nix — rust-overlay channels,
  toolchainFile, Moon/prek/treefmt, sccache/mold, bindgen, LD_LIBRARY_PATH, and
  buildRustPackage patterns. Use when adding Rust to a devenv shell, fixing NixOS
  linker or bindgen errors, or aligning with ~/Code/rust workspace conventions.
---

# Rust + NixOS + devenv.nix

Status-quo patterns from `~/Code/rust` workspaces and [devenv Rust docs](https://devenv.sh/languages/rust/). This repo is Python-first but shares Moon, prek, treefmt, and lean-ctx wiring — reuse the same shell discipline when Rust crates land here.

## Before changing devenv

1. Read existing `devenv.yaml` inputs and `devenv.nix` — do not duplicate toolchain config in `rust-toolchain.toml` **and** manual `channel`/`version` (devenv asserts on conflict).
2. Prefer **one source of truth** for the toolchain (see decision tree below).
3. All cargo/moon commands: `devenv shell -- …` (NixOS has no usable system Rust).

## Toolchain decision tree

```
Project has rust-toolchain.toml?
  yes → languages.rust = { enable = true; toolchainFile = ./rust-toolchain.toml; }
  no  → channel = "stable" | "nightly" (rust-overlay, NOT "nixpkgs" for app workspaces)
        + explicit components + optional version = "latest" | "1.xx.0"
```

| Channel | When | Notes |
|---------|------|-------|
| `toolchainFile` | Repo already pins `rust-toolchain.toml` | Best DRY; uses oxalica `fromRustupToolchainFile` |
| `stable` | Default for apps (`forge`, `streamweave`, `syo`) | Pin `version` when CI must be reproducible |
| `nightly` | `rustc_private`, Dylint, Miri, Cranelift dev | `id_effect` uses nightly + `rustc-dev` |
| `nixpkgs` | Avoid for serious Rust workspaces | Tied to nixpkgs rev; limited components |

### devenv.yaml inputs (required for non-nixpkgs channels)

```yaml
inputs:
  nixpkgs:
    url: github:cachix/devenv-nixpkgs/rolling
  rust-overlay:
    url: github:oxalica/rust-overlay
    inputs:
      nixpkgs:
        follows: nixpkgs
```

devenv pulls `rust-overlay` automatically when `channel != "nixpkgs"`. Declaring the input explicitly matches `id_effect` and avoids pin drift.

### Canonical `languages.rust` block (stable app)

Pattern from `forge`, `streamweave`, `solana-yield-optimizer`:

```nix
languages.rust = {
  enable = true;
  channel = "stable";
  components = [
    "cargo"
    "clippy"
    "rust-analyzer"
    "rustc"
    "rustfmt"
    "llvm-tools"   # cargo-llvm-cov
  ];
  targets = [];    # add cross targets explicitly, e.g. wasm32-unknown-unknown
};
```

### Nightly + compiler plugins (`id_effect`)

```nix
languages.rust = {
  enable = true;
  channel = "nightly";
  components = [
    "cargo" "clippy" "rust-analyzer" "rustc" "rustc-dev" "rust-src"
    "rustfmt" "llvm-tools"
  ];
  targets = [];
};
```

## Packages to add (Rust workspace standard)

Add to `packages = with pkgs; [ … ]` — do **not** rely on rustup outside the shell.

| Package | Purpose |
|---------|---------|
| `cargo-watch` | Dev reload |
| `cargo-audit` | Security advisories (`moon :audit`) |
| `cargo-nextest` | Fast parallel tests |
| `cargo-llvm-cov` | Coverage gates |
| `sccache` | Compilation cache |
| `mold` | Fast linker (Linux) |
| `lldb` | Debugger |
| `prek` | Git hooks (replaces pre-commit Python stack) |
| `treefmt` + `rustfmt` + `taplo` + `deadnix` + `alejandra` | Format/lint Nix+Rust+TOML |
| `moon` | Task runner (often pinned via `fetchurl` in `let` block) |

Optional: `mdbook` (id_effect book), `ast-grep`, `vulnix`.

## Environment variables (status quo)

```nix
env = {
  CARGO_TERM_COLOR = "always";
  RUST_BACKTRACE = "1";                    # forge, streamweave
  MOON_TOOLCHAIN_FORCE_GLOBALS = "rust";   # use devenv Rust, not proto/rustup
  MOON_CONCURRENCY = "1";                  # avoid cargo lock contention in hooks
  NEXTEST_NO_TESTS = "pass";               # nextest exit 4 → pass for empty crates
  OPENSSL_NO_VENDOR = "1";                 # use nixpkgs openssl (id_effect)
  # RUSTC_WRAPPER = "sccache";             # forge sets explicitly; id_effect uses default ~/.cache/sccache
};
```

### NixOS runtime linking

Python/Rust mixed shells (`syo`, this repo) often need:

```nix
env.LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [
  pkgs.stdenv.cc.cc.lib
  pkgs.zlib
  # + project-specific: openssl, vips, glib, …
];
```

**Rule:** set `LD_LIBRARY_PATH` in the `env` block, not only in `enterShell` — re-exporting in `enterShell` can clobber earlier entries (see timeseries-stationarity numpy/zlib comment).

### bindgen / `-sys` crates (lightgbm, drift, etc.)

```nix
env = {
  LIBCLANG_PATH = "${pkgs.llvmPackages.libclang.lib}/lib";
  BINDGEN_EXTRA_CLANG_ARGS = "-isystem ${gcc}/include/c++/${gccVer}/…";  # match stdenv.cc
};
packages = [ pkgs.llvmPackages.libclang.lib pkgs.cmake pkgs.protobuf ];
```

GCC version in bindgen args must match `stdenv.cc` — Nix installs under `include/c++/<full-version>/`, not major-only.

## enterShell hook pattern

Standard sequence from `id_effect` / `forge` / `syo`:

```nix
enterShell = ''
  mkdir -p "$DEVENV_ROOT/tmp"
  export TMPDIR="$DEVENV_ROOT/tmp"

  prek-install    # or rely on devenv:git-hooks:install task
  moon-sync

  mkdir -p "$HOME/.cache/sccache"
  chmod 755 "$HOME/.cache/sccache" 2>/dev/null || true

  # Optional: prepend locally built CLI
  # export PATH="$PWD/target/debug:$PATH"
'';
```

### prek + Moon scripts

```nix
scripts = {
  prek-install.exec = ''prek install -q --overwrite'';
  moon-sync.exec = ''moon sync'';
  pre-push.exec = ''
    export MOON_TOOLCHAIN_FORCE_GLOBALS=rust
    export MOON_CONCURRENCY=1
    mkdir -p "$DEVENV_ROOT/tmp"
    export TMPDIR="$DEVENV_ROOT/tmp"
    moon run :format :check :build :test :coverage :audit
  '';
};
```

Gate composition varies by repo (`id_effect` adds `:check-docs :docs`; this repo uses definitively YAML programs).

## Moon + Rust workspace

Typical root `moon.yml` (id_effect):

- `:format` / `:ci-format` — treefmt (check vs write)
- `:check` — `cargo check`
- `:clippy` — `-D warnings`, depends on ci-format
- `:test` — `cargo nextest` per crate
- `:coverage` — `cargo llvm-cov nextest` with `--fail-under-*`
- `:audit` — `cargo audit`
- `:build` — `cargo build`

Member crates inherit via `^:test` / `^:clippy` deps. Set `language: rust` on each crate project.

## Building Rust tools inside devenv.nix

Pin CLI crates with `pkgs.rustPlatform.buildRustPackage` (lean-ctx in `syo` / this repo):

```nix
lean-ctx-pkg = pkgs.rustPlatform.buildRustPackage rec {
  pname = "lean-ctx";
  version = "3.1.5";
  src = pkgs.fetchCrate { inherit pname version; hash = "…"; };
  cargoHash = "…";
  doCheck = false;  # upstream tests need full dev shell
};
```

Name the binding `lean-ctx-pkg` (not `lean-ctx`) so `with pkgs` does not pick nixpkgs' homonym.

## Linker speedups

devenv options (prefer over manual `.cargo/config.toml` when possible):

```nix
languages.rust.mold.enable = true;   # Linux — id_effect adds mold to packages
languages.rust.lld.enable = true;    # macOS-friendly
# languages.rust.cranelift.enable = true;  # nightly dev builds only
```

## NixOS pitfalls

| Symptom | Fix |
|---------|-----|
| `libz.so.1 not found` at runtime | Add `zlib` to `LD_LIBRARY_PATH` |
| PyPI wheel / binary won't run | Use nix-packaged tool (`ty`, `beads`) or build in devenv |
| Moon downloads its own Rust | Set `MOON_TOOLCHAIN_FORCE_GLOBALS=rust` |
| bindgen can't find libstdc++ headers | `BINDGEN_EXTRA_CLANG_ARGS` with full GCC path |
| Hook hangs on cargo lock | `MOON_CONCURRENCY=1`, `TMPDIR=$DEVENV_ROOT/tmp` |
| Duplicate toolchain config | Use `toolchainFile` **or** `channel`+`version`, never both |
| rust-analyzer wrong version | Match analyzer component to same overlay channel |

## Adding Rust to this repo (Python + devenv today)

This workspace has `MOON_TOOLCHAIN_FORCE_GLOBALS=rust` but no `languages.rust` yet. To add Rust crates:

1. Add `rust-overlay` to `devenv.yaml` if using stable/nightly overlay.
2. Add `languages.rust` block + cargo packages listed above.
3. Add `rust-toolchain.toml` at repo root; prefer `toolchainFile = ./rust-toolchain.toml`.
4. Extend treefmt inputs for `**/*.rs`.
5. Add Moon Rust projects under `crates/` or `rust/`.

## Verification checklist

After devenv changes:

```bash
devenv shell -- rustc --version
devenv shell -- cargo --version
devenv shell -- cargo clippy --version
devenv shell -- moon --version
devenv shell -- moon run :check :test   # once moon projects exist
```

On NixOS, confirm a test binary runs: `devenv shell -- cargo test -p <crate> -- --nocapture`.

## References

- [devenv Rust module](https://devenv.sh/languages/rust/)
- [oxalica/rust-overlay](https://github.com/oxalica/rust-overlay)
- [NixOS nixpkgs Rust manual](https://nixos.org/manual/nixpkgs/stable/#rust)
- Local exemplars: `~/Code/rust/id_effect/devenv.nix`, `forge/devenv.nix`, `solana-yield-optimizer/devenv.nix`
