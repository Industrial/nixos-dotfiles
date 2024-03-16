{
  settings,
  pkgs,
  ...
}: {
  imports = [
    # CLI
    ../../../features/system/cli/bat
    ../../../features/system/cli/btop
    ../../../features/system/cli/direnv
    ../../../features/system/cli/e2fsprogs
    ../../../features/system/cli/eza
    ../../../features/system/cli/fd
    ../../../features/system/cli/fish
    ../../../features/system/cli/fzf
    ../../../features/system/cli/gh
    ../../../features/system/cli/neofetch
    ../../../features/system/cli/p7zip
    ../../../features/system/cli/ranger
    ../../../features/system/cli/ripgrep
    ../../../features/system/cli/starship
    ../../../features/system/cli/unrar
    ../../../features/system/cli/unzip
    ../../../features/system/cli/zellij

    # Communication
    ../../../features/system/communication/discord

    # Media
    ../../../features/system/media/spotify

    # Office
    ../../../features/system/office/evince
    ../../../features/system/office/obsidian

    # Programming
    # ../../../features/system/programming/nixd
    ../../../features/system/programming/git
    ../../../features/system/programming/gitkraken
    ../../../features/system/programming/nodejs
    ../../../features/system/programming/sqlite

    # Nix
    ../../../features/system/nix/home-manager
    ../../../features/system/nix/nix-unit
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
