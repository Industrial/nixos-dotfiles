# Colocated suite: V-268126 — at least one uppercase character required.
let
  assay = import ./../../../../common/assay/default.nix;
  fixture = import ./../lib/fixture.nix;
  mod = import ./V-268126.nix {};
  config = fixture.evalWith [./../default.nix ./V-268126.nix];
  rendered = config.environment.etc."security/pwquality.conf".text;
in
  assay.suite "stig-V-268126" {
    ucredit = assay.eq mod.security.stig.pwquality.ucredit (-1);

    # Negative means "require one"; positive would grant length credit instead, which the
    # check explicitly treats as a finding.
    isEnforcementNotCredit = assay.eq (mod.security.stig.pwquality.ucredit < 0) true;

    # Lands in the file the check greps, in the form it greps for.
    reachesRenderedFile = assay.eq (builtins.match ".*ucredit=-1.*" rendered != null) true;
    # Rendered at /etc/security/..., not the fix text's /etc//security/...
    etcPathHasNoDoubleSlash = assay.eq (builtins.hasAttr "security/pwquality.conf" config.environment.etc) true;
  }
