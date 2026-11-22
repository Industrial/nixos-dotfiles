# Offload nix builds to fleet machines. The builder list and each machine's capacity
# live in common/fleet.nix; hosts marked `online = false` there are left out.
#
# Nix's build hook does not skip an unreachable builder quickly: it can pick one and
# wait out the TCP connect timeout (minutes) for a derivation. Measured on mimir,
# 2026-11-22: 28 remote builds of ~15 s total took 36.7 min, ~80 s apart, while
# huginn and muninn were offline (GH-252). So the builders also get a short ssh
# ConnectTimeout in the system ssh_config, which the nix-daemon's ssh (root) reads.
{
  lib,
  settings,
  ...
}: let
  fleet = import ../../common/fleet.nix;
  connectTimeout = 5;
in {
  nix.distributedBuilds = true;

  nix.buildMachines =
    map (b: {
      hostName = b.name;
      system = "x86_64-linux";
      inherit (b) maxJobs speedFactor supportedFeatures;
      sshUser = settings.username;
      sshKey = "${settings.userdir}/.ssh/id_ed25519";
    })
    fleet.builders;

  nix.settings.builders-use-substitutes = true;

  programs.ssh.extraConfig = lib.mkIf (fleet.builders != []) ''
    Host ${lib.concatMapStringsSep " " (b: b.name) fleet.builders}
      ConnectTimeout ${toString connectTimeout}
  '';
}
