# Colocated suite: V-268174 — accounts disabled after 35 days of inactivity.
let
  assay = import ./../../../../common/assay/default.nix;
  fixture = import ./../lib/fixture.nix;
  # Evaluated against the real nixpkgs modules: programs/shadow.nix defines the same file,
  # and the two definitions meeting is what this control has to survive.
  config = fixture.evalWith [./V-268174.nix];
  file = config.environment.etc."default/useradd";
  lines = builtins.filter (l: builtins.isString l && l != "") (builtins.split "\n" file.text);
  has = pattern: builtins.any (l: builtins.match pattern l != null) lines;
in
  assay.suite "stig-V-268174" {
    setsInactive = assay.eq (builtins.elem "INACTIVE=35" lines) true;

    # No leading slash: the fix text's "/default/useradd" renders to /etc//default/useradd.
    etcPathHasNoLeadingSlash = assay.eq (builtins.hasAttr "default/useradd" config.environment.etc) true;
    doesNotUseTheSlashedPath = assay.eq (builtins.hasAttr "/default/useradd" config.environment.etc) false;

    # The fix text's mkForce replaces the file with one line. This keeps the three that
    # nixpkgs writes there.
    keepsShadowsDefaults = assay.eq [(has "GROUP=100") (has "HOME=/.*") (has "SHELL=/.*")] [true true true];

    # nixpkgs defines this file's `source` too. Forcing the name of the merged source proves
    # the two definitions resolve instead of conflicting, which they did not before.
    resolvesAgainstNixpkgsDefinition = assay.eq (builtins.isString file.source.name) true;
  }
