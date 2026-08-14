# Host package: cargo-built wrapper against the local rust workspace (dev-first).
# Requires the .dotfiles checkout at runtime
# (DOTFILES_ROOT / NIX_HASH_ROOT / DEVENV_ROOT / git toplevel). Same approach as rust/tools/*/default.nix.
{
  lib,
  pkgs,
  rustc ? pkgs.rustc,
  cargo ? pkgs.cargo,
  ...
}:
pkgs.writeShellApplication {
  name = "nix-hash";
  runtimeInputs = [
    cargo
    rustc
    pkgs.gcc
    pkgs.pkg-config
    pkgs.git
  ];
  text = ''
    set -euo pipefail
    root="''${DOTFILES_ROOT:-''${NIX_HASH_ROOT:-''${DEVENV_ROOT:-}}}"
    if [[ -z "$root" ]]; then
      root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
    fi
    if [[ -z "$root" || ! -f "$root/rust/Cargo.toml" ]]; then
      echo "nix-hash: set DOTFILES_ROOT to your .dotfiles checkout (need rust/Cargo.toml)" >&2
      exit 127
    fi
    manifest="$root/rust/Cargo.toml"
    bin="$root/rust/target/release/nix-hash"
    debug="$root/rust/target/debug/nix-hash"
    if [[ ! -x "$bin" ]]; then
      bin="$debug"
    fi
    needs_build=0
    if [[ ! -x "$bin" ]]; then
      needs_build=1
    else
      newest="$(find "$root/rust/tools/nix-hash/src" -type f -newer "$bin" 2>/dev/null | head -n1 || true)"
      if [[ -n "$newest" ]]; then
        needs_build=1
      fi
    fi
    if [[ "$needs_build" -eq 1 ]]; then
      echo "nix-hash: building (cargo -p nix-hash --release)…" >&2
      env -u RUSTC_WRAPPER cargo build --release --manifest-path "$manifest" -p nix-hash
      bin="$root/rust/target/release/nix-hash"
    fi
    exec "$bin" "$@"
  '';
}
