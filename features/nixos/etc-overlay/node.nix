# The drakkar node shared by features/nixos/etc-overlay's VM tests (GH-185): drakkar's own
# hosts/drakkar/configuration.nix (every profile and feature it enables, plus hardware.nix
# and filesystems.nix) with only disko.nix disabled: its LUKS + btrfs layout cannot exist
# in a VM, and qemu-vm supplies the root filesystem instead.
#
# One package set: drakkar's own (its nixpkgs.config and overlays already applied), shared
# by the node and every extension or specialisation of it. Left to the nodes, each module
# evaluation instantiates nixpkgs again, which put a check past CI's 8 GiB eval budget
# (bin/ci/flake-checks). Every check built on this evaluates drakkar at most twice.
{inputs}: let
  inherit (inputs.nixpkgs) lib;
  inherit
    (import ../../../common/settings.nix {
      hostname = "drakkar";
      useremail = "tom.wieland@gmail.com";
    })
    settings
    ;
  features = import ../../../lib/features.nix {inherit lib;};
  drakkarPkgs = (import ../../../lib/mk-host.nix {inherit inputs;} "drakkar").pkgs;
in {
  # runNixOSTest's `node` option.
  node = {
    pkgsReadOnly = false;
    specialArgs = {inherit inputs settings;};
  };

  module = {
    imports =
      features.modules
      ++ [
        {system.configurationRevision = "gh-185-test";}
        ../../../hosts/drakkar/configuration.nix
      ];
    disabledModules = [../../../hosts/drakkar/disko.nix];

    # Already carries drakkar's config and overlays, so the modules' own are dropped here
    # (the nixpkgs module refuses `config` next to `pkgs`, and would re-apply `overlays`).
    nixpkgs = {
      pkgs = lib.mkForce drakkarPkgs;
      config = lib.mkForce {};
      overlays = lib.mkForce [];
    };

    # VM-only adjustments, the minimum for drakkar's config to coexist with qemu-vm.
    services.timesyncd.enable = lib.mkForce false;
    systemd.settings.Manager.DefaultTimeoutStartSec = lib.mkForce 300;

    virtualisation = {
      cores = 4;
      memorySize = 6144;
      diskSize = 8192;
    };
  };
}
