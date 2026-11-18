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
    ../features/finance/tws
    # ../features/finance/ib-gateway
    # ../features/programming/meld
    ../features/programming/neovim
    # ../features/programming/terraform
    # ../features/programming/vscode
    # ../features/programming/bun
    ../features/programming/cursor
    ../features/programming/devenv
    ../features/programming/emerald
    # Lighter alternatives to cursor above, both on trial. They coexist with it
    # rather than replacing it: all three can be installed at once, and the one
    # that costs RAM is the one you actually open. Neither ships rust-analyzer —
    # see the header comments for the measurement that decided that.
    ../features/programming/helix
    ../features/programming/zed
    ../features/programming/voltaic
    ../features/programming/docker-compose
    ../features/programming/git
    ../features/programming/gitkraken
    ../features/programming/openidea
    # ../features/programming/glogg
    # ../features/programming/insomnia
    # ../features/programming/node
    # ../features/programming/pgadmin
    # ../features/programming/python
    # ../features/programming/zig
  ];
}
