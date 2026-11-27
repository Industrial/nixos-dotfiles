# The oracle for host/src/oracle.vlt: the same derivation, instantiated by Nix
# on the nixpkgs this repository pins.
#
#   nix eval --json --file rust/spikes/voltaic-modules/oracle.nix \
#     --apply "f: f { rev = \"$(git rev-parse HEAD)\"; }"
#
# `git+file` with a rev, never `path:` or a bare directory, which would copy
# .git into the store (#266).
{rev}: let
  flake = builtins.getFlake "git+file:///home/tom/.dotfiles?rev=${rev}";
  pkgs = flake.inputs.nixpkgs.legacyPackages.x86_64-linux;
  d = derivation {
    name = "s1b-hello";
    system = "x86_64-linux";
    builder = "${pkgs.bash}/bin/bash";
    args = [
      "-c"
      "echo \"hi\" > $out"
    ];
  };
in {
  drv = d.drvPath;
  out = d.outPath;
  bashDrv = pkgs.bash.drvPath;
  bashOut = pkgs.bash.outPath;
}
