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
  name = "nixq";
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
      echo "nixq: set DOTFILES_ROOT to your .dotfiles checkout (need rust/Cargo.toml)" >&2
      exit 127
    fi
    manifest="$root/rust/Cargo.toml"
    bin="$root/rust/target/release/nixq"
    debug="$root/rust/target/debug/nixq"
    if [[ ! -x "$bin" ]]; then
      bin="$debug"
    fi
    needs_build=0
    if [[ ! -x "$bin" ]]; then
      needs_build=1
    else
      newest="$(find "$root/rust/tools/nixq/src" -type f -newer "$bin" 2>/dev/null | head -n1 || true)"
      if [[ -n "$newest" ]]; then
        needs_build=1
      fi
    fi
    if [[ "$needs_build" -eq 1 ]]; then
      echo "nixq: building (cargo -p nixq --release)…" >&2
      env -u RUSTC_WRAPPER cargo build --release --manifest-path "$manifest" -p nixq
      bin="$root/rust/target/release/nixq"
    fi
    exec "$bin" "$@"
  '';
}
