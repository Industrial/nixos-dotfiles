{
  settings,
  pkgs,
  ...
}: {
  imports = [
    # CLI
    ../../../features/cli/bat
    ../../../features/cli/btop
    ../../../features/cli/direnv
    ../../../features/cli/e2fsprogs
    ../../../features/cli/eza
    ../../../features/cli/fd
    ../../../features/cli/fish
    ../../../features/cli/fzf
    ../../../features/cli/gh
    ../../../features/cli/neofetch
    ../../../features/cli/p7zip
    ../../../features/cli/ranger
    ../../../features/cli/ripgrep
    ../../../features/cli/starship
    ../../../features/cli/unrar
    ../../../features/cli/unzip
    ../../../features/cli/zellij

    # Communication
    ../../../features/communication/discord

    # Media
    ../../../features/media/spotify

    # Office
    ../../../features/office/evince
    ../../../features/office/obsidian

    # Programming
    # ../../../features/programming/nixd
    ../../../features/programming/git
    ../../../features/programming/gitkraken
    ../../../features/programming/nodejs
    ../../../features/programming/sqlite

    # Nix
    ../../../features/nix/nix-unit
    ../../../features/nix/shell
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
