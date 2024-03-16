let
  pkgs = import <nixpkgs> {};
  settings = import ../../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    name = "chromium_test";
    actual = builtins.elem pkgs.ungoogled-chromium feature.environment.systemPackages;
    expected = true;
  }
]
