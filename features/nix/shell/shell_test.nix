let
  pkgs = import <nixpkgs> {};
  settings = import ../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    name = "shell_test/programs.bash.enable";
    actual = feature.programs.bash.enable;
    expected = true;
  }
  {
    name = "shell_test/programs.fish.enable";
    actual = feature.programs.fish.enable;
    expected = true;
  }
  {
    name = "shell_test/environment.shells";
    actual = feature.environment.shells;
    expected = with pkgs; [bashInteractive fish];
  }
  {
    name = "shell_test/feature.users.users.${settings.username}.shell";
    actual = feature.users.users."${settings.username}".shell;
    expected = pkgs.fish;
  }
]
