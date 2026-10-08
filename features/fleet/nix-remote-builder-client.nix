# Offload nix builds to fleet machines. Nix skips unreachable hosts automatically.
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
    {
      hostName = "muninn";
      system = "x86_64-linux";
      maxJobs = 4;
      speedFactor = 1;
      supportedFeatures = ["kvm" "nixos-test"];
      sshUser = settings.username;
      sshKey = "${settings.userdir}/.ssh/id_ed25519";
    }
    {
      hostName = "huginn";
      system = "x86_64-linux";
      maxJobs = 4;
      speedFactor = 1;
      supportedFeatures = ["kvm" "nixos-test"];
      sshUser = settings.username;
      sshKey = "${settings.userdir}/.ssh/id_ed25519";
    }
  ];

  nix.settings.builders-use-substitutes = true;
}
