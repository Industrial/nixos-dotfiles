# Host package: cargo-built wrapper against the local rust workspace (dev-first).
# Requires the .dotfiles checkout at runtime
# (DOTFILES_ROOT / DEVENV_ROOT / git toplevel).
{
  lib,
  pkgs,
  rustc ? pkgs.rustc,
  cargo ? pkgs.cargo,
  ...
}:
pkgs.writeShellApplication {
  name = "nixstore";
  runtimeInputs = [
    cargo
    rustc
    pkgs.gcc
    pkgs.pkg-config
    pkgs.git
  ];
  text = ''
    set -euo pipefail
    root="''${DOTFILES_ROOT:-''${DEVENV_ROOT:-}}"
    if [[ -z "$root" ]]; then
      root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
    fi
    if [[ -z "$root" || ! -f "$root/rust/Cargo.toml" ]]; then
      echo "nixstore: set DOTFILES_ROOT to your .dotfiles checkout (need rust/Cargo.toml)" >&2
      exit 127
    fi
    manifest="$root/rust/Cargo.toml"
    bin="$root/rust/target/release/nixstore"
    debug="$root/rust/target/debug/nixstore"
    if [[ ! -x "$bin" ]]; then
      bin="$debug"
    fi
    needs_build=0
    if [[ ! -x "$bin" ]]; then
      needs_build=1
    else
      newest="$(find "$root/rust/tools/nixstore/src" -type f -newer "$bin" 2>/dev/null | head -n1 || true)"
      if [[ -n "$newest" ]]; then
        needs_build=1
      fi
    fi
    if [[ "$needs_build" -eq 1 ]]; then
      echo "nixstore: building (cargo -p nixstore --release)…" >&2
      env -u RUSTC_WRAPPER cargo build --release --manifest-path "$manifest" -p nixstore
      bin="$root/rust/target/release/nixstore"
    fi
    exec "$bin" "$@"
  '';
}
