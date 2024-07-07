args @ {pkgs, ...}: let
  feature = import ./default.nix args;
in {
  test_services_openssh_enable = {
    expr = feature.services.openssh.enable;
    expected = true;
  };
}
