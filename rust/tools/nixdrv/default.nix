# nixdrv library for devenv: cargo-built (path-deps to local id_effect).
{
  lib,
  pkgs,
  rustc ? pkgs.rustc,
  cargo ? pkgs.cargo,
  ...
}:
pkgs.writeShellApplication {
  name = "nixdrv";
  runtimeInputs = [
    cargo
    rustc
    pkgs.gcc
    pkgs.pkg-config
    pkgs.git
  ];
  text = ''
    set -euo pipefail
    root="''${DEVENV_ROOT:-}"
    if [[ -z "$root" ]]; then
      root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
    fi
    manifest="$root/rust/Cargo.toml"
    bin="$root/rust/target/debug/nixdrv"
    if [[ ! -f "$manifest" ]]; then
      echo "nixdrv: cannot find rust workspace at $manifest" >&2
      exit 127
    fi
    needs_build=0
    if [[ ! -x "$bin" ]]; then
      needs_build=1
    else
      newest="$(find "$root/rust/tools/nixdrv/src" -type f -newer "$bin" | head -n1 || true)"
      if [[ -n "$newest" ]]; then
        needs_build=1
      fi
    fi
    if [[ "$needs_build" -eq 1 ]]; then
      echo "nixdrv: building (cargo -p nixdrv)…" >&2
      env -u RUSTC_WRAPPER cargo build --manifest-path "$manifest" -p nixdrv
    fi
    exec "$bin" "$@"
  '';
}
