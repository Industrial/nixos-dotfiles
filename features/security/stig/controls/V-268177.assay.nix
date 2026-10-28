# Colocated suite: V-268177 — second factor from a separate device.
let
  assay = import ./../../../../common/assay/default.nix;
  fixture = import ./../lib/fixture.nix;
  mod = import ./V-268177.nix {};
  # With V-268176 (UsePAM) from base-safe, so the factor reaches remote sessions.
  config = fixture.evalWith [{services.openssh.enable = true;} ./V-268176.nix ./V-268177.nix];
in
  assay.suite "stig-V-268177" {
    p11Enabled = assay.eq mod.security.pam.p11.enable true;
    reachesEvaluatedConfig = assay.eq config.security.pam.p11.enable true;

    # Not a nixpkgs default — this is the control that actually requires the token, unlike
    # V-268136 which only installs PKCS#11 support.
    isNotADefault = assay.eq (fixture.evalWith []).security.pam.p11.enable false;

    # Depends on UsePAM to cover SSH; without it a PAM factor guards the console only.
    sshGoesThroughPam = assay.eq config.services.openssh.settings.UsePAM true;
    sshdPamStackExists = assay.eq (builtins.hasAttr "sshd" config.security.pam.services) true;
  }
