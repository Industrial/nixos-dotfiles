{
  settings,
  pkgs,
  ...
}: {
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

  nixpkgs.hostPlatform = settings.system;
  services.nix-daemon.enable = true;

  # Use shells from nix. `chsh -s /run/current-system/sw/bin/fish`
  programs.bash.enable = true;
  programs.zsh.enable = true;
  programs.fish.enable = true;
  environment.shells = with pkgs; [bashInteractive fish zsh];

  system.stateVersion = 4;
}
