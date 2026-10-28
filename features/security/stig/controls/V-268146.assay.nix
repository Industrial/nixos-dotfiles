# Colocated suite: V-268146 (CAT I) — wireless disabled.
let
  assay = import ./../../../../common/assay/default.nix;
  fixture = import ./../lib/fixture.nix;
  mod = import ./V-268146.nix {};
in
  assay.suite "stig-V-268146" {
    wirelessDisabled = assay.eq mod.networking.wireless.enable false;

    # Already the nixpkgs default, and already the fleet's evaluated value, because these
    # hosts use NetworkManager rather than wpa_supplicant. So this control is a no-op that
    # the check nonetheless scores as compliant while Wi-Fi keeps working through
    # NetworkManager. Pinned so that gap stays visible rather than being mistaken for
    # protection.
    isAlreadyTheDefault = assay.eq (fixture.evalWith []).networking.wireless.enable false;
  }
