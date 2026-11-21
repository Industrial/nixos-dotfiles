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

    # dust is installed under its own name; nothing shadows coreutils' `du`. A system-wide `du`
    # wrapper broke every bash script and `sudo du` (it exec'd the dust store directory, and dust's
    # flags are not du's anyway: -h is help, -s is apparent size). Interactive nushell has its own
    # builtin `du`, so the wrapper bought nothing.
    carriesDustNotDuWrapper = assay.eq [(has "cli.dust") (has "cli.du")] [true false];

    # vdiff is what `bin/dev build` diffs a fresh closure with (GH-153); nvd stays installed
    # alongside it, but nothing in the flow calls it any more.
    carriesVdiff = assay.eq [(has "cli.vdiff") (has "cli.nvd")] [true true];

    # cli-core is CLI only: nothing outside features/cli.
    onlyCliFeatures = assay.eq (builtins.filter (f: builtins.substring 0 4 f != "cli.") on) [];
  }
