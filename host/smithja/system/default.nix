{
  settings,
  pkgs,
  ...
}: {
  imports = [
    # CLI
    ../../../features/system/cli/fish

    # Nix
    ../../../features/system/nix/home-manager
    ../../../features/system/nix/shell
  ];

  # TODO: Put this in a module.
  nix.package = pkgs.nixFlakes;

  # TODO: This should be taken care of for all hosts / systems.
  nix.settings.experimental-features = "nix-command flakes";

  nixpkgs.hostPlatform = settings.system;
  services.nix-daemon.enable = true;

  programs.bash.enable = true;
  environment.shells = with pkgs; [bashInteractive fish];

  system.stateVersion = 4;
}
