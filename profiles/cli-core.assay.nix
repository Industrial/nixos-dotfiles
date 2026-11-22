# Colocated suite for profiles/cli-core.nix — evaluated selection, not source text.
let
  assay = import ../common/assay/default.nix;
  nixos = import ../common/assay/nixos.nix;
  features = import ../lib/features.nix {inherit (nixos) lib;};
  on = features.enabledFeatures (features.evalSelection {modules = [{profiles.cli-core.enable = true;}];});
  has = f: builtins.elem f on;
  # The rollback for vwhy's take-over (GH-182): one option, set beside the profile.
  rolledBack = features.enabledFeatures (features.evalSelection {
    modules = [
      {profiles.cli-core.enable = true;}
      {features.cli.nix-tree.enable = true;}
    ];
  });
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

    # vdiff took over from nvd (GH-153): it is what `bin/dev build` diffs a fresh closure with,
    # and nvd is no longer installed by the profile.
    vdiffReplacesNvd = assay.eq [(has "cli.vdiff") (has "cli.nvd")] [true false];

    # The rollback is one option: a host that sets features.cli.nvd.enable gets nvd back,
    # next to vdiff.
    nvdIsTheRollback = let
      rolledBack = features.enabledFeatures (features.evalSelection {modules = [{profiles.cli-core.enable = true;} {features.cli.nvd.enable = true;}];});
    in
      assay.eq [(builtins.elem "cli.vdiff" rolledBack) (builtins.elem "cli.nvd" rolledBack)] [true true];

    # vmon took over from nix-output-monitor (GH-181): bin/dev, bin/update and bin/fleet build
    # through it, and nom is not installed beside it.
    vmonReplacesNom = assay.eq [(has "cli.vmon") (has "cli.nix-output-monitor")] [true false];

    # The rollback is one option: a host that turns vmon off gets nom back (and bin/dev falls
    # back to it), with nothing else to change.
    rollbackRestoresNom = let
      off = features.enabledFeatures (features.evalSelection {
        modules = [
          ({lib, ...}: {
            profiles.cli-core.enable = true;
            features.cli.vmon.enable = lib.mkForce false;
          })
        ];
      });
    in
      assay.eq [(builtins.elem "cli.vmon" off) (builtins.elem "cli.nix-output-monitor" off)] [false true];

    # vwhy answers "why is this in my closure" and "what makes it big" (GH-182): it is on the
    # default path and nix-tree is not. `features.cli.nix-tree.enable = true` is the one-option
    # rollback, and it keeps vwhy installed beside nix-tree.
    carriesVwhyNotNixTree = assay.eq [(has "cli.vwhy") (has "cli.nix-tree")] [true false];
    nixTreeRollsBack = assay.eq [(builtins.elem "cli.vwhy" rolledBack) (builtins.elem "cli.nix-tree" rolledBack)] [true true];

    # vswitch took over from nh and nixos-rebuild (GH-241): bin/update/system switches
    # through it, and nh is not installed beside it.
    vswitchReplacesNh = assay.eq [(has "cli.vswitch") (has "cli.nh")] [true false];

    # The rollback is one option: a host that turns vswitch off gets nh back (and
    # bin/update/system falls back to nixos-rebuild), with nothing else to change.
    rollbackRestoresNh = let
      off = features.enabledFeatures (features.evalSelection {
        modules = [
          ({lib, ...}: {
            profiles.cli-core.enable = true;
            features.cli.vswitch.enable = lib.mkForce false;
          })
        ];
      });
    in
      assay.eq [(builtins.elem "cli.vswitch" off) (builtins.elem "cli.nh" off)] [false true];

    # cli-core is CLI only: nothing outside features/cli.
    onlyCliFeatures = assay.eq (builtins.filter (f: builtins.substring 0 4 f != "cli.") on) [];
  }
