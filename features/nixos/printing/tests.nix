args @ {pkgs, ...}: let
  feature = import ./default.nix args;
in {
  test_services_printing_enable = {
    expr = feature.services.printing.enable;
    expected = true;
  };
  test_environment_systemPackages = {
    expr = builtins.elem pkgs.cnijfilter2 feature.environment.systemPackages;
    expected = true;
  };
}
