# Colocated suite for profiles/base.nix — evaluated selection, not source text.
let
  assay = import ../common/assay/default.nix;
  nixos = import ../common/assay/nixos.nix;
  features = import ../lib/features.nix {inherit (nixos) lib;};
  cfg = features.evalSelection {modules = [{profiles.base.enable = true;}];};
  on = features.enabledFeatures cfg;
  has = f: builtins.elem f on;
in
  assay.suite "base" {
    # base carries the headless-safe CLI set via cli-core, not cli-desktop.
    enablesCliCore = assay.eq cfg.profiles.cli-core.enable true;
    leavesCliDesktopOff = assay.eq cfg.profiles.cli-desktop.enable false;

    enablesCoreNixos = assay.eq (has "nixos") true;
    enablesUsers = assay.eq (has "nixos.users") true;

    # The STIG option surface must be on every host (flake.nix builds stigReport for all
    # four), but the base-safe control set is mimir's alone — ADR-0004.
    enablesStigSurface = assay.eq (has "security.stig") true;
    enablesExternalEvidence = assay.eq (has "security.stig.profiles.external-evidence") true;
    leavesBaseSafeOff = assay.eq (has "security.stig.profiles.base-safe") false;
  }
