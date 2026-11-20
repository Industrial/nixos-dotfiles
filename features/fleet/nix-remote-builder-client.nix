# Offload nix builds to fleet machines. Nix skips unreachable hosts automatically.
# The builder list and each machine's capacity live in common/fleet.nix.
{settings, ...}: let
  fleet = import ../../common/fleet.nix;
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
}
