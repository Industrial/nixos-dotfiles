# Colocated suite: V-268176 (CAT I) — SSH authenticates through PAM.
let
  assay = import ./../../../../common/assay/default.nix;
  fixture = import ./../lib/fixture.nix;
  mod = import ./V-268176.nix {};
  config = fixture.evalWith [{services.openssh.enable = true;} ./V-268176.nix];
in
  assay.suite "stig-V-268176" {
    # A bool, not the string "yes" the fix text asks for.
    usePam = assay.eq mod.services.openssh.settings.UsePAM true;
    isBoolNotString = assay.eq (builtins.isBool mod.services.openssh.settings.UsePAM) true;

    reachesEvaluatedConfig = assay.eq config.services.openssh.settings.UsePAM true;

    # The consequence that makes this control matter: nixpkgs only wires up the sshd PAM stack
    # when UsePAM is true, which is what lets the PAM-side controls reach remote sessions.
    sshdPamServiceExists = assay.eq (builtins.hasAttr "sshd" config.security.pam.services) true;
  }
