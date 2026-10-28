# Colocated suite: V-268145 — at least one special character required.
let
  assay = import ./../../../../common/assay/default.nix;
  fixture = import ./../lib/fixture.nix;
  mod = import ./V-268145.nix {};
  config = fixture.evalWith [./../default.nix ./V-268145.nix];
  rendered = config.environment.etc."security/pwquality.conf".text;
in
  assay.suite "stig-V-268145" {
    ocredit = assay.eq mod.security.stig.pwquality.ocredit (-1);
    isEnforcementNotCredit = assay.eq (mod.security.stig.pwquality.ocredit < 0) true;
    reachesRenderedFile = assay.eq (builtins.match ".*ocredit=-1.*" rendered != null) true;
  }
