# Colocated suite: V-268127 — at least one lowercase character required.
let
  assay = import ./../../../../common/assay/default.nix;
  fixture = import ./../lib/fixture.nix;
  mod = import ./V-268127.nix {};
  config = fixture.evalWith [./../default.nix ./V-268126.nix ./V-268127.nix];
  rendered = config.environment.etc."security/pwquality.conf".text;
in
  assay.suite "stig-V-268127" {
    lcredit = assay.eq mod.security.stig.pwquality.lcredit (-1);
    isEnforcementNotCredit = assay.eq (mod.security.stig.pwquality.lcredit < 0) true;
    reachesRenderedFile = assay.eq (builtins.match ".*lcredit=-1.*" rendered != null) true;

    # Two controls writing the same file must both survive — this is the merge the six
    # published fix texts could not do.
    coexistsWithUcredit = assay.eq (builtins.match ".*ucredit=-1.*" rendered != null) true;
  }
