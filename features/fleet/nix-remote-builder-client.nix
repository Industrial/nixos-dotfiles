# Offload nix builds to Drakkar when this host is online.
{settings, ...}: {
  nix.distributedBuilds = true;

  nix.buildMachines = [
    {
      hostName = "drakkar";
      system = "x86_64-linux";
      maxJobs = 8;
      speedFactor = 2;
      supportedFeatures = ["big-parallel" "kvm" "nixos-test"];
      sshUser = settings.username;
      sshKey = "${settings.userdir}/.ssh/id_ed25519";
    }
  ];

  nix.settings.builders-use-substitutes = true;
}
