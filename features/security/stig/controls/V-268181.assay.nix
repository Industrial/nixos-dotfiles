# Colocated suite: V-268181 — owner-only default permissions.
let
  assay = import ./../../../../common/assay/default.nix;
  fixture = import ./../lib/fixture.nix;
  mod = import ./V-268181.nix {};
  config = fixture.evalWith [./V-268181.nix];
in
  assay.suite "stig-V-268181" {
    umask = assay.eq mod.security.loginDefs.settings.UMASK "077";
    reachesEvaluatedConfig = assay.eq config.security.loginDefs.settings.UMASK "077";

    # nixpkgs ALREADY defaults UMASK to 077, so this control is a restatement rather than a
    # change — verified here rather than assumed, because the first draft of this suite
    # asserted the opposite and failed. Declaring it anyway is deliberate: the report should
    # prove the value, not inherit it from a default that a later nixpkgs could relax.
    nixpkgsDefaultIsAlready077 = assay.eq (fixture.evalWith []).security.loginDefs.settings.UMASK "077";

    # A string, not an int: 077 as a number would be decimal seventy-seven.
    isOctalString = assay.eq (builtins.isString mod.security.loginDefs.settings.UMASK) true;
  }
