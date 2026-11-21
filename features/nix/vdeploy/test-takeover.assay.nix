# Colocated suite for features/nix/vdeploy/test-takeover.nix, the LIVE take-over from comin
# and back (#160, brief rule 17). Evaluates the test's node, so the claims are about the
# machine under test; no VM is booted here (`nix build
# .#checks.x86_64-linux.vdeploy-takeover-vm` runs it).
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  pkgs = nixos.flakeInputs.nixpkgs.legacyPackages.x86_64-linux;

  takeover = import ./test-takeover.nix {inherit pkgs;};
  t = takeover.nodes.machine;
  spec = name: t.specialisation.${name}.configuration;
  probesOf = c: builtins.attrNames c.features.nix.vhealth.probes;
  inherit (t.systemd.services) comin;
in
  assay.suite "vdeploy-takeover-vm-test" {
    named = assay.eq takeover.name "vm-test-run-vdeploy-takeover-vm";
    # Boots WITHOUT the take-over; comin's stand-in has comin's unit shape.
    bootsWithoutTheTakeover = assay.eq t.features.nix.vdeploy.mode "observe";
    standInLikeComin = assay.eq [comin.restartIfChanged comin.serviceConfig.Restart comin.wantedBy] [false "always" ["multi-user.target"]];
    takeoverHasTheTombstone =
      assay.eq [(spec "takeover").features.nix.vdeploy.mode (spec "takeover").systemd.services.comin.serviceConfig.Restart (spec "takeover").systemd.services.comin.wantedBy] ["deploy" "no" []];
    # The negative control drops comin's unit with no tombstone.
    naiveDropsComin = assay.eq [((spec "naive").systemd.services ? comin) (spec "naive").features.nix.vdeploy.mode] [false "observe"];
    everyGenerationIsProbed = assay.eq (map (g: builtins.elem "web" (probesOf (spec g))) ["takeover" "good" "naive"]) [true true true];
  }
