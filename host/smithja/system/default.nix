{pkgs, ...}: {
  imports = [
    # CLI
    ../../../features/system/cli/fish
    ../../../features/system/cli/p7zip
    ../../../features/system/cli/starship
    ../../../features/system/cli/unrar

    # Network
    # ../../../features/system/network/syncthing

    # Nix
    ../../../features/system/nix/home-manager
    ../../../features/system/nix/shell

    # Programming
    ../../../features/system/programming/git
  ];

  # TODO: Put this in a module.
  nix.package = pkgs.nixFlakes;

  # TODO: This should be taken care of for all hosts / systems.
  nix.settings.experimental-features = "nix-command flakes";

  nixpkgs.hostPlatform = "aarch64-darwin";
  services.nix-daemon.enable = true;

  system.stateVersion = 4;
}
