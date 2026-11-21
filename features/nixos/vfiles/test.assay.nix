# Colocated suite for features/nixos/vfiles/test.nix, the VM test that adds and removes a
# feature's files, adopts, falls back, and reports drift.
#
# Evaluates the test's node (no VM is booted here; `nix build .#checks.x86_64-linux.vfiles-vm`
# runs it), so these claims are about the machine under test: vfiles on, the base files,
# and a specialisation that adds the extra feature's.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  pkgs = nixos.flakeInputs.nixpkgs.legacyPackages.x86_64-linux;

  test = import ./test.nix {inherit pkgs;};
  inherit (test.nodes) machine;
  extra = machine.specialisation.extra.configuration;
in
  assay.suite "vfiles-vm-test" {
    named = assay.eq test.name "vm-test-run-vfiles-vm";
    runsVfiles = assay.eq (machine.system.activationScripts ? vfiles) true;
    baseFiles = assay.eq (builtins.attrNames machine.vfiles.files) [
      "/home/alice/.config/base/copied.conf"
      "/home/alice/.config/base/linked.conf"
      "/home/alice/.config/hypr/hyprland.lua"
    ];
    fallbackForTheCheckout = assay.eq machine.vfiles.files."/home/alice/.config/hypr/hyprland.lua".source "/home/alice/checkout/hyprland.lua";
    # The specialisation inherits the three base files and adds two.
    inheritsTheBaseAndAddsTwo = assay.eq (builtins.length (builtins.attrNames extra.vfiles.files)) 5;
    everyFileIsAlices = assay.eq (builtins.all (f: f.user == "alice") (builtins.attrValues machine.vfiles.files)) true;
  }
