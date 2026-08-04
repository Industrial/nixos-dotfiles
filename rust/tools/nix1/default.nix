# nix1 / nix1-hash for devenv: cargo-built (path-deps).
{
  lib,
  pkgs,
  rustc ? pkgs.rustc,
  cargo ? pkgs.cargo,
  ...
}:
pkgs.writeShellApplication {
  name = "nix1-hash";
  runtimeInputs = [
    cargo
    rustc
    pkgs.gcc
    pkgs.pkg-config
  ];
  text = ''
    set -euo pipefail
    root="''${DEVENV_ROOT:-}"
    if [[ -z "$root" ]]; then
      root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
    fi
    manifest="$root/rust/Cargo.toml"
    bin="$root/rust/target/debug/nix1-hash"
    if [[ ! -f "$manifest" ]]; then
      echo "nix1-hash: cannot find rust workspace at $manifest" >&2
      exit 127
    fi
    needs_build=0
    if [[ ! -x "$bin" ]]; then
      needs_build=1
    else
      newest="$(find "$root/rust/tools/nix1/src" "$root/rust/tools/nixfetch/src" -type f -newer "$bin" 2>/dev/null | head -n1 || true)"
      if [[ -n "$newest" ]]; then
        needs_build=1
      fi
    fi
    if [[ "$needs_build" -eq 1 ]]; then
      echo "nix1-hash: building (cargo -p nix1)…" >&2
      env -u RUSTC_WRAPPER cargo build --manifest-path "$manifest" -p nix1
    fi
    exec "$bin" "$@"
  '';
}
