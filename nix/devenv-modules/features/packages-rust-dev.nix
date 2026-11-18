{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.local.features.packages-rust-dev;
in {
  options.local.features.packages-rust-dev.enable = lib.mkEnableOption "Rust toolchain helpers (cargo-*, sccache, mold, lldb)";

  config = lib.mkIf cfg.enable {
    # Do not add pkgs.rustc / clippy / rust-analyzer / rustfmt here — they come from
    # languages.rust (rust-overlay) and nixpkgs copies shadow that toolchain on PATH
    # (seen as rustc 1.94.0 vs cargo nightly → MSRV failures for nautilus/alloy).
    packages = with pkgs; [
      lldb
      cargo-watch
      cargo-audit
      cargo-llvm-cov
      cargo-nextest
      sccache
      mold
      llvmPackages.libclang.lib
    ];

    enterShell = lib.mkBefore ''
      mkdir -p "$HOME/.cache/sccache"
      chmod 755 "$HOME/.cache/sccache" 2>/dev/null || true
    '';
  };
}
