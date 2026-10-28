# Colocated suite: V-268128 — at least one numeric character required.
let
  assay = import ./../../../../common/assay/default.nix;
  fixture = import ./../lib/fixture.nix;
  mod = import ./V-268128.nix {};
  config = fixture.evalWith [./../default.nix ./V-268128.nix];
  rendered = config.environment.etc."security/pwquality.conf".text;
in
  assay.suite "stig-V-268128" {
    dcredit = assay.eq mod.security.stig.pwquality.dcredit (-1);
    isEnforcementNotCredit = assay.eq (mod.security.stig.pwquality.dcredit < 0) true;
    reachesRenderedFile = assay.eq (builtins.match ".*dcredit=-1.*" rendered != null) true;
  }
