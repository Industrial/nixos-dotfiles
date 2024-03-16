let
  pkgs = import <nixpkgs> {};
  settings = import ../../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    actual = feature.programs.fish.enable;
    expected = true;
  }
  {
    actual = feature.users.users."${settings.username}".shell;
    expected = pkgs.fish;
  }
]
