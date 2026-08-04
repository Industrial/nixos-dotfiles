# Assay CLI for devenv: cargo-built binary (path-deps to local id_effect).
# Avoids crate2nix / buildRustPackage path-copy of the whole id_effect tree.
{
  lib,
  pkgs,
  rustc ? pkgs.rustc,
  cargo ? pkgs.cargo,
  ...
}:
pkgs.writeShellApplication {
  name = "assay";
  runtimeInputs = [
    cargo
    rustc
    pkgs.gcc
    pkgs.pkg-config
    pkgs.nix
    pkgs.git
  ];
  text = ''
    set -euo pipefail
    root="''${DEVENV_ROOT:-}"
    if [[ -z "$root" ]]; then
      root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
    fi
    manifest="$root/rust/Cargo.toml"
    bin="$root/rust/target/debug/assay"
    if [[ ! -f "$manifest" ]]; then
      echo "assay: cannot find rust workspace at $manifest" >&2
      exit 127
    fi
    # Rebuild when missing or when sources are newer than the binary.
    needs_build=0
    if [[ ! -x "$bin" ]]; then
      needs_build=1
    else
      newest="$(find "$root/rust/tools/assay/src" -type f -newer "$bin" | head -n1 || true)"
      if [[ -n "$newest" ]]; then
        needs_build=1
      fi
    fi
    if [[ "$needs_build" -eq 1 ]]; then
      echo "assay: building (cargo -p assay)…" >&2
      env -u RUSTC_WRAPPER cargo build --manifest-path "$manifest" -p assay
    fi
    exec "$bin" "$@"
  '';
}
