let
  pkgs = import <nixpkgs> {};
  settings = import ../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    name = "nix_test";
    actual = feature.system.stateVersion;
    expected = settings.stateVersion;
  }
  {
    name = "nix_test";
    actual = feature.nix.package;
    expected = pkgs.nixFlakes;
  }
  {
    name = "nix_test";
    actual = feature.nix.extraOptions;
    expected = ''
      experimental-features = nix-command flakes
    '';
  }
  {
    name = "nix_test";
    actual = feature.nix.settings.trusted-users;
    expected = ["root" "${settings.username}"];
  }
  {
    name = "nix_test";
    actual = feature.nix.settings.allow-import-from-derivation;
    expected = true;
  }
]
