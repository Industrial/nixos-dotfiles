# Colocated suite for features/cli/nixos-update-notifier
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./default.nix;
in
  assay.suite "features-cli-nixos-update-notifier" {
    nonEmpty = assay.eq ((builtins.stringLength src) > 0) true;
    hasUserTimer = assay.eq (builtins.match ".*systemd.user.timers.nixos-update-notifier.*" src != null) true;
  }
