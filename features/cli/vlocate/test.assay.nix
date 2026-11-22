# Colocated suite for features/cli/vlocate/test.nix (GH-245). Evaluates the test's node; no
# VM is booted here (`nix build .#checks.x86_64-linux.vlocate-vm` runs it).
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  pkgs = nixos.flakeInputs.nixpkgs.legacyPackages.x86_64-linux;
  inherit (pkgs) lib;

  test = import ./test.nix {inherit pkgs;};
  m = test.nodes.machine;
in
  assay.suite "vlocate-vm-test" {
    named = assay.eq test.name "vm-test-run-vlocate-vm";
    # cowsay is in the system's closure but not installed: what a hint is for.
    cowsayInClosureNotOnPath = assay.eq [(builtins.elem pkgs.cowsay m.system.extraDependencies) (builtins.elem pkgs.cowsay m.environment.systemPackages)] [true false];
    allThreeShells = assay.eq [m.programs.fish.enable m.programs.zsh.enable (builtins.elem pkgs.nushell m.environment.systemPackages)] [true true true];
    aFleetRoot = assay.eq (lib.any (r: lib.hasInfix "/var/lib/vci/roots/main-mimir" r) m.systemd.tmpfiles.rules) true;
  }
