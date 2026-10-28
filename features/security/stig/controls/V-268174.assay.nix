# Colocated suite: V-268174 — accounts disabled after 35 days of inactivity.
let
  assay = import ./../../../../common/assay/default.nix;
  mod = import ./V-268174.nix {};
in
  assay.suite "stig-V-268174" {
    setsInactive = assay.eq (builtins.match ".*INACTIVE=35.*" mod.environment.etc."default/useradd".text != null) true;

    # No leading slash: the fix text's "/default/useradd" renders to /etc//default/useradd.
    etcPathHasNoLeadingSlash = assay.eq (builtins.hasAttr "default/useradd" mod.environment.etc) true;
    doesNotUseTheSlashedPath = assay.eq (builtins.hasAttr "/default/useradd" mod.environment.etc) false;

    # Not mkForce: the fix text's mkForce would discard shadow's GROUP/HOME/SHELL defaults
    # from the same file.
    doesNotForceTheWholeFile = assay.eq (mod.environment.etc."default/useradd".text._type or null) null;
  }
