# Colocated suite for common/vhealth-probes.nix — the `features.nix.vhealth.probes.<name>`
# option, alone: its defaults, its types, and that importing it twice declares it once.
let
  assay = import ./assay/default.nix;
  nixos = import ./assay/nixos.nix;

  cfg = nixos.eval {
    modules = [
      ./vhealth-probes.nix
      ./vhealth-probes.nix
      {
        features.nix.vhealth.probes.web = {
          type = "http";
          url = "http://127.0.0.1/";
        };
      }
    ];
  };
  inherit (cfg.features.nix.vhealth.probes) web;
  bad = builtins.tryEval (builtins.deepSeq
    (nixos.eval {
      modules = [
        ./vhealth-probes.nix
        {features.nix.vhealth.probes.x.type = "ping";}
      ];
    })
    .features
    .nix
    .vhealth
    .probes
    .x
    .type
    true);
in
  assay.suite "vhealth-probes-option" {
    declaredOnceWhenImportedTwice = assay.eq (builtins.attrNames cfg.features.nix.vhealth.probes) ["web"];
    defaults = assay.eq [web.timeout web.critical web.status web.argv web.host web.port web.maxAge] [5000 true 200 [] null null null];
    unknownTypeRefused = assay.eq bad.success false;
    noProbesByDefault = assay.eq (nixos.eval {modules = [./vhealth-probes.nix];}).features.nix.vhealth.probes {};
  }
