# Colocated suite: V-268078 — built-in firewall enabled.
let
  assay = import ./../../../../common/assay/default.nix;
  mod = import ./V-268078.nix {};
in
  assay.suite "stig-V-268078" {
    firewallEnabled = assay.eq mod.networking.firewall.enable true;
  }
