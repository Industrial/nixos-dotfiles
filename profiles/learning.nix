# Learning Profile
# Learning and documentation tools
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

    ../features/learning/anki
    ../features/learning/foliate
    ../features/learning/zotero
  ];
}
