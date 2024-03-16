let
  pkgs = import <nixpkgs> {};
  settings = import ../../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    actual = feature.system.stateVersion;
    expected = settings.stateVersion;
  }
  {
    actual = feature.nix.package;
    expected = pkgs.nixFlakes;
  }
  {
    actual = feature.nix.extraOptions;
    expected = ''
      experimental-features = nix-command flakes
    '';
  }
  {
    actual = feature.nix.settings.trusted-users;
    expected = ["root" "${settings.username}"];
  }
  {
    actual = feature.nix.settings.allow-import-from-derivation;
    expected = true;
  }
]
