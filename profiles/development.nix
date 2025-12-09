# Development Profile
# Development tools and programming environments
{
  config,
  lib,
  pkgs,
  inputs,
  settings,
  ...
}: {
  imports = [
    ./base.nix

    # Programming Tools
    ../features/programming/bun
    ../features/programming/cursor
    ../features/programming/devenv
    ../features/programming/docker-compose
    ../features/programming/git
    ../features/programming/gitkraken
    ../features/programming/glogg
    ../features/programming/insomnia
    ../features/programming/meld
    ../features/programming/neovim
    ../features/programming/node
    ../features/programming/python
    # ../features/programming/vscode
    # ../features/programming/terraform
  ];
}
