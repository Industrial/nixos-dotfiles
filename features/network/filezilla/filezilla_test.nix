let
  pkgs = import <nixpkgs> {};
  settings = import ../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    name = "filezilla_test";
    actual = builtins.elem pkgs.filezilla feature.environment.systemPackages;
    expected = true;
  }
]
