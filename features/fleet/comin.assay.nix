# Assay: comin pull-convergence feature.
#
# Guards the invariants that make pull-convergence safe alongside deploy-rs
# push (see docs/adr/0002-comin-pull-convergence.md). Evaluated against the real
# comin module at its flake.lock revision, so an option comin renames or removes
# fails here instead of on a host.
let
  assay = import ../../common/assay/default.nix;
  nixos = import ../../common/assay/nixos.nix;
  cfg = nixos.eval {
    modules = [./comin.nix];
    settings.hostname = "mimir";
  };
  comin = cfg.services.comin;
  origin = builtins.head comin.remotes;
in
  assay.suite "comin" {
    enablesComin = assay.eq comin.enable true;

    # Must select nixosConfigurations.<hostname> from the unified root flake.
    usesSettingsHostname = assay.eq comin.hostname "mimir";

    # repositorySubdir must stay at its default "." — the pre-ADR-0001
    # per-host-flake value (hosts/<hostname>) silently breaks eval.
    repositorySubdirIsRoot = assay.eq comin.repositorySubdir ".";

    singleOriginRemote = assay.eq (map (r: r.name) comin.remotes) ["origin"];
    pullsMainWithSwitch = assay.subset origin.branches.main {
      name = "main";
      operation = "switch";
    };

    # Convergence must be observable, not merely asserted — but only on the tailnet.
    exportsMetrics = assay.eq comin.exporter.port 4243;
    metricsPortNotPublished = assay.eq (builtins.elem 4243 (nixos.openTCPPorts cfg)) false;
  }
