# Colocated suite for profiles/cli-desktop.nix
let
  assay = import ./../common/assay/default.nix;
  src = builtins.readFile ./cli-desktop.nix;
  has = feature: builtins.match ".*features/cli/${feature} .*" src != null;
in
  assay.suite "cli-desktop" {
    hasImports = assay.eq (builtins.match ".*imports.*=.*" src != null) true;

    # nixos-update-notifier is the clearest case in the file: its user timer wants
    # graphical-session.target, so on a seatless host the unit can never fire.
    carriesSessionBoundNotifier = assay.eq (has "nixos-update-notifier") true;

    # The other direction of the same guard as cli-core's: a core entry duplicated here would
    # be installed twice in intent and would survive a host dropping profiles/desktop.nix only
    # by accident.
    carriesNoCoreEntry = assay.eq (has "ripgrep") false;
  }
