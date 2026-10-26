# Assay: comin pull-convergence feature.
#
# Guards the invariants that make pull-convergence safe alongside deploy-rs
# push (see docs/adr/0002-comin-pull-convergence.md).
let
  assay = import ../../common/assay/default.nix;
  src = builtins.readFile ./comin.nix;
in
  assay.suite "comin" {
    # The module is not in nixpkgs; it must come from the flake input.
    importsCominFlakeModule = assay.eq (builtins.match ".*inputs\\.comin\\.nixosModules\\.comin.*" src != null) true;

    enablesComin = assay.eq (builtins.match ".*services\\.comin.*enable = true.*" src != null) true;

    # Must select nixosConfigurations.<hostname> from the unified root flake.
    usesSettingsHostname = assay.eq (builtins.match ".*hostname = settings\\.hostname.*" src != null) true;

    # repositorySubdir must stay at its default "." — the pre-ADR-0001
    # per-host-flake value (hosts/<hostname>) silently breaks eval. Anchored to
    # a line-leading assignment so prose mentioning the option cannot trip it.
    noStaleRepositorySubdir =
      assay.eq (builtins.match ".*\n[[:space:]]*repositorySubdir[[:space:]]*=.*" src != null) false;

    pullsOriginMainWithSwitch =
      assay.eq (builtins.match ".*name = \"main\".*operation = \"switch\".*" src != null) true;

    # Convergence must be observable, not merely asserted.
    exportsMetrics = assay.eq (builtins.match ".*exporter.*port = 4243.*" src != null) true;
  }
