let
  pkgs = import <nixpkgs> {};
  settings = import ../../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in {
  testPackages = {
    expr = builtins.elem pkgs.yubikey-manager feature.environment.systemPackages;
    expected = true;
  };
}
