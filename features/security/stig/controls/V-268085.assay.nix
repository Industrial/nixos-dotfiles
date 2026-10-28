# Colocated suite: V-268085 — concurrent sessions capped at 10.
let
  assay = import ./../../../../common/assay/default.nix;
  fixture = import ./../lib/fixture.nix;
  mod = import ./V-268085.nix {};
  config = fixture.evalWith [./V-268085.nix];
  limit = builtins.head mod.security.pam.loginLimits;

  maxlogins = builtins.filter (l: l.item == "maxlogins") config.security.pam.loginLimits;
in
  assay.suite "stig-V-268085" {
    exactlyOneLimit = assay.eq (builtins.length mod.security.pam.loginLimits) 1;

    appliesToAllDomains = assay.eq limit.domain "*";
    isMaxlogins = assay.eq limit.item "maxlogins";
    # `hard` so a user cannot raise it; `soft` would be advisory only.
    isHardLimit = assay.eq limit.type "hard";
    valueIsTen = assay.eq limit.value "10";

    # Appends to the existing loginLimits list rather than replacing it.
    reachesEvaluatedConfig = assay.eq (builtins.length maxlogins) 1;
  }
