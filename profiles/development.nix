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
    # ../features/programming/meld
    # ../features/programming/neovim
    # ../features/programming/terraform
    # ../features/programming/vscode
    ../features/programming/bun
    ../features/programming/cursor
    ../features/programming/devenv
    ../features/programming/docker-compose
    ../features/programming/git
    ../features/programming/gitbutler
    ../features/programming/gitkraken
    ../features/programming/glogg
    ../features/programming/insomnia
    ../features/programming/node
    ../features/programming/pgadmin
    ../features/programming/python
  ];
}
