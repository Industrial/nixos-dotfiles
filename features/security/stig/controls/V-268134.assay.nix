# Colocated suite: V-268134 — 15-character minimum password length.
let
  assay = import ./../../../../common/assay/default.nix;
  fixture = import ./../lib/fixture.nix;
  mod = import ./V-268134.nix {};
  # Merged with a base-safe pwquality control to prove the shared file still composes.
  config = fixture.evalWith [./../default.nix ./V-268126.nix ./V-268129.nix ./V-268134.nix];
  rendered = config.environment.etc."security/pwquality.conf".text;
in
  assay.suite "stig-V-268134" {
    minlen = assay.eq mod.security.stig.pwquality.minlen 15;
    reachesRenderedFile = assay.eq (builtins.match ".*minlen=15.*" rendered != null) true;

    # Merges with the base-safe settings rather than replacing the file.
    coexistsWithCreditSettings = assay.eq (builtins.match ".*ucredit=-1.*" rendered != null) true;
    coexistsWithDifok = assay.eq (builtins.match ".*difok=8.*" rendered != null) true;

    # The pairing that makes V-268129 mean "50 percent": 8 changed characters out of a
    # 15-character minimum. Pinned so the relationship is not lost if either moves.
    difokIsHalfOfMinlen = assay.eq (8 * 2 >= mod.security.stig.pwquality.minlen) true;
  }
