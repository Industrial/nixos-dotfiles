# A fleet host as the node of features/nixos/etc-overlay's VM tests (GH-185): the host's
# own hosts/<hostname>/configuration.nix (every profile and feature it enables, plus
# hardware.nix and filesystems.nix) with only disko.nix disabled: its LUKS + btrfs layout
# cannot exist in a VM, and qemu-vm supplies the root filesystem instead. drakkar unless
# told otherwise; the live-switch gate runs once per host (flake.nix,
# etc-overlay-live-switch and etc-overlay-live-switch-<host>).
#
# One package set: the host's own (its nixpkgs.config and overlays already applied), shared
# by the node and every extension or specialisation of it. Left to the nodes, each module
# evaluation instantiates nixpkgs again, which put a check past CI's 8 GiB eval budget
# (bin/ci/flake-checks). Every check built on this evaluates its host at most twice.
{
  inputs,
  hostname ? "drakkar",
}: let
  inherit (inputs.nixpkgs) lib;
  inherit
    (import ../../../common/settings.nix {
      inherit hostname;
      useremail = "tom.wieland@gmail.com";
    })
    settings
    ;
  features = import ../../../lib/features.nix {inherit lib;};
  hostPkgs = (import ../../../lib/mk-host.nix {inherit inputs;} hostname).pkgs;
  host = ../../../hosts + "/${hostname}";
in {
  inherit hostname settings;

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
        (host + "/configuration.nix")
      ];
    disabledModules = [(host + "/disko.nix")];

    # Already carries the host's config and overlays, so the modules' own are dropped here
    # (the nixpkgs module refuses `config` next to `pkgs`, and would re-apply `overlays`).
    nixpkgs = {
      pkgs = lib.mkForce hostPkgs;
      config = lib.mkForce {};
      overlays = lib.mkForce [];
    };

    # Every test starts from the host WITHOUT the feature, also once the host enables it:
    # this beats the host's plain `true`, and the live-switch gate's extension turns it
    # back on with lib.mkForce (test-live-switch.nix).
    features.nixos.etc-overlay.enable = lib.mkOverride 60 false;

    # VM-only adjustments, the minimum for a host's config to coexist with qemu-vm.
    services.timesyncd.enable = lib.mkForce false;
    systemd.settings.Manager.DefaultTimeoutStartSec = lib.mkForce 300;
    # huginn resumes from a swapfile in its LUKS container, which is disko's: in a VM the
    # initrd would wait for /dev/mapper/cryptroot. The default (no resume device) elsewhere.
    boot.resumeDevice = lib.mkForce "";

    virtualisation = {
      cores = 4;
      memorySize = 6144;
      diskSize = 8192;
    };
  };
}
