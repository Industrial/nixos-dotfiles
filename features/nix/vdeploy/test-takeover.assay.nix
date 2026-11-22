# Colocated suite for features/nix/vdeploy/test-takeover.nix, the take-over's end state
# switched in and out live (GH-225, brief rule 17). Evaluates the test's node, so the claims
# are about the machine under test; no VM is booted here (`nix build
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
    # Boots in the hosts' state before GH-225: deploy mode, comin a tombstone.
    bootsWithTheTombstone =
      assay.eq [t.features.nix.vdeploy.mode comin.restartIfChanged comin.wantedBy comin.serviceConfig.Restart] ["deploy" false [] "no"];
    # The end state the hosts get: deploy mode and no comin.service at all.
    endStateHasNoComin =
      assay.eq (map (g: [(spec g).features.nix.vdeploy.mode ((spec g).systemd.services ? comin)]) ["retired" "good"]) [["deploy" false] ["deploy" false]];
    everyGenerationIsProbed = assay.eq (map (g: builtins.elem "web" (probesOf (spec g))) ["retired" "good"]) [true true];
  }
