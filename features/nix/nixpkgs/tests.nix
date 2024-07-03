args @ {settings, ...}: let
  feature = import ./default.nix args;
in {
  test_allowUnfree = {
    expr = feature.nixpkgs.config.allowUnfree;
    expected = true;
  };
  test_allowBroken = {
    expr = feature.nixpkgs.config.allowBroken;
    expected = false;
  };
  test_hostPlatform = {
    expr = feature.nixpkgs.hostPlatform;
    expected = settings.hostPlatform;
  };
}
