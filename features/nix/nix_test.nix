let
  pkgs = import <nixpkgs> {};
  settings = import ../../../host/test/settings.nix;
  feature = import ./default.nix {inherit pkgs settings;};
in [
  {
    name = "nix_test/system.stateVersion";
    actual = feature.system.stateVersion;
    expected = settings.stateVersion;
  }
  {
    name = "nix_test/nix.package";
    actual = feature.nix.package;
    expected = pkgs.nixFlakes;
  }
  {
    name = "nix_test/nix.settings.experimental-features";
    actual = feature.nix.settings.experimental-features;
    expected = "nix-command flakes";
  }
  {
    name = "nix_test/nix.settings.allow-import-from-derivation";
    actual = feature.nix.settings.allow-import-from-derivation;
    expected = true;
  }
]
