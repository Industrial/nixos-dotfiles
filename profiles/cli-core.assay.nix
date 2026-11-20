# Colocated suite for profiles/cli-core.nix — evaluated selection, not source text.
let
  assay = import ../common/assay/default.nix;
  nixos = import ../common/assay/nixos.nix;
  features = import ../lib/features.nix {inherit (nixos) lib;};
  on = features.enabledFeatures (features.evalSelection {modules = [{profiles.cli-core.enable = true;}];});
  has = f: builtins.elem f on;
in
  assay.suite "cli-core" {
    # The multiplexer is the load-bearing core entry: an ssh-only host that loses zellij loses
    # every long-running job to a dropped connection.
    carriesMultiplexer = assay.eq (has "cli.zellij") true;

    # Guard the split's direction. calcurse lives in cli-desktop; if it reappears here the
    # boundary has eroded and a headless host is carrying a calendar again.
    carriesNoDesktopOnlyEntry = assay.eq (has "cli.calcurse") false;

    # cli-core is CLI only: nothing outside features/cli.
    onlyCliFeatures = assay.eq (builtins.filter (f: builtins.substring 0 4 f != "cli.") on) [];
  }
