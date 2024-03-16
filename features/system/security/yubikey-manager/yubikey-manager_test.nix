let
  pkgs = import <nixpkgs> {};
  settings = import ../../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    actual = builtins.elem pkgs.yubikey-manager feature.environment.systemPackages;
    expected = true;
  }
  {
    actual = builtins.elem pkgs.yubikey-manager-qt feature.environment.systemPackages;
    expected = true;
  }
  {
    actual = builtins.elem pkgs.yubikey-personalization-gui feature.environment.systemPackages;
    expected = true;
  }
]
