args @ {pkgs, ...}: let
  feature = import ./default.nix args;
in {
  test_environment_systemPackages_transmission_4 = {
    expr = builtins.elem pkgs.transmission_4 feature.environment.systemPackages;
    expected = true;
  };
  test_environment_systemPackages_transmission_4-gtk = {
    expr = builtins.elem pkgs.transmission_4-qt feature.environment.systemPackages;
    expected = true;
  };
}
