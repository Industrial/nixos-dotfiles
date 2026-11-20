# Colocated suite for profiles/cli-desktop.nix — evaluated selection, not source text.
let
  assay = import ../common/assay/default.nix;
  nixos = import ../common/assay/nixos.nix;
  features = import ../lib/features.nix {inherit (nixos) lib;};
  on = features.enabledFeatures (features.evalSelection {modules = [{profiles.cli-desktop.enable = true;}];});
  core = features.enabledFeatures (features.evalSelection {modules = [{profiles.cli-core.enable = true;}];});
  has = f: builtins.elem f on;
in
  assay.suite "cli-desktop" {
    # nixos-update-notifier is the clearest case in the file: its user timer wants
    # graphical-session.target, so on a seatless host the unit can never fire.
    carriesSessionBoundNotifier = assay.eq (has "cli.nixos-update-notifier") true;

    # The other direction of the same guard as cli-core's: no entry may sit in both lists,
    # or it would survive a host dropping profiles/desktop.nix only by accident.
    carriesNoCoreEntry = assay.eq (builtins.filter (f: builtins.elem f core) on) [];
    carriesNoRipgrep = assay.eq (has "cli.ripgrep") false;
  }
