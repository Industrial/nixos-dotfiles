# Colocated suite: V-268169 — dictionary words rejected.
let
  assay = import ./../../../../common/assay/default.nix;
  fixture = import ./../lib/fixture.nix;
  mod = import ./V-268169.nix {};
  # All six pwquality controls together: the real test is that they merge into one file.
  config = fixture.evalWith [
    ./../default.nix
    ./V-268126.nix
    ./V-268127.nix
    ./V-268128.nix
    ./V-268129.nix
    ./V-268145.nix
    ./V-268169.nix
  ];
  rendered = config.environment.etc."security/pwquality.conf".text;
  has = key: builtins.match ".*${key}.*" rendered != null;
in
  assay.suite "stig-V-268169" {
    dictcheck = assay.eq mod.security.stig.pwquality.dictcheck 1;
    reachesRenderedFile = assay.eq (has "dictcheck=1") true;

    # All six controls that share this file survive together. Following the published fix
    # texts literally would have been six conflicting definitions of one option.
    allSixSettingsPresent =
      assay.eq (builtins.all has [
        "ucredit=-1"
        "lcredit=-1"
        "dcredit=-1"
        "ocredit=-1"
        "difok=8"
        "dictcheck=1"
      ])
      true;
    renderedLineCount = assay.eq (builtins.length (builtins.filter (l: builtins.isString l && l != "") (builtins.split "\n" rendered))) 6;
  }
