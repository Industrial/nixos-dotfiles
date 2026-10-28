# Colocated suite: V-268172 (CAT I) — no unattended console logon.
#
# The control is an assertion rather than a setting, because the secure state is the nixpkgs
# default and what matters is that a host has not turned autologin on. So both directions are
# exercised: default must pass, autologin enabled must fail.
let
  assay = import ./../../../../common/assay/default.nix;
  nixpkgsLib = (import <nixpkgs> {}).lib;

  control = autoLogin:
    import ./V-268172.nix {
      lib = nixpkgsLib;
      config.services.displayManager = {inherit autoLogin;};
    };

  verdict = mod: (builtins.head mod.assertions).assertion;

  defaultState = control {enable = false;};
  autologinOn = control {
    enable = true;
    user = "tom";
  };
in
  assay.suite "stig-V-268172" {
    passesWithAutologinOff = assay.eq (verdict defaultState) true;
    failsWithAutologinOn = assay.eq (verdict autologinOn) false;

    # The message names the account, so the finding is actionable.
    messageNamesTheUser =
      assay.eq (builtins.match ".*user = tom.*" (builtins.head autologinOn.assertions).message != null) true;

    # ...and records that the published fix text names a non-existent option, so the
    # divergence is documented where someone will read it.
    messageRecordsTheBadOptionPath =
      assay.eq (builtins.match ".*not a real option.*" (builtins.head autologinOn.assertions).message != null) true;
  }
