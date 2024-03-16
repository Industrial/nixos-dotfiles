let
  pkgs = import <nixpkgs> {};
  settings = import ../../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    name = "shell_test";
    actual = feature.programs.fish.enable;
    expected = true;
  }
  {
    name = "shell_test";
    actual = feature.users.users."${settings.username}".shell;
    expected = pkgs.fish;
  }
]
