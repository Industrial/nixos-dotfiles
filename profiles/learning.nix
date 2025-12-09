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

    # Learning and Documentation
    ../features/learning/zotero
    ../features/learning/anki
  ];
}
