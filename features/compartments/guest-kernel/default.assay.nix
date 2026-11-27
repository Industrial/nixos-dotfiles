# Assay: the compartments guest-kernel feature (#425). The Kconfig surface is pinned
# by config.assay.nix, the derivation by package.assay.nix.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  cfg = (nixos.evalSystem {modules = [./default.nix];}).config;
in
  assay.suite "guest-kernel" {
    # Enabled, the host carries the kernel under /etc for its VMMs, and nothing else.
    shipsUnderEtc = assay.eq (cfg.environment.etc ? "compartments/guest-kernel") true;
  }
