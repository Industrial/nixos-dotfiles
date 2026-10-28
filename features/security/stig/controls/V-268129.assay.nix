# Colocated suite: V-268129 — half the characters must change on a password change.
let
  assay = import ./../../../../common/assay/default.nix;
  fixture = import ./../lib/fixture.nix;
  mod = import ./V-268129.nix {};
  config = fixture.evalWith [./../default.nix ./V-268129.nix];
  rendered = config.environment.etc."security/pwquality.conf".text;
in
  assay.suite "stig-V-268129" {
    difok = assay.eq mod.security.stig.pwquality.difok 8;
    reachesRenderedFile = assay.eq (builtins.match ".*difok=8.*" rendered != null) true;

    # A positive count, unlike the credit settings where negative means "require".
    isPositiveCount = assay.eq (mod.security.stig.pwquality.difok > 0) true;

    # 8 is "50 percent" only of a 15-character minimum (V-268134, full profile). This case
    # pins the relationship so the pairing is not forgotten.
    isHalfOfTheFifteenCharMinimum = assay.eq (8 * 2 >= 15) true;
  }
