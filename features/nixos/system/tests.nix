args @ {...}: let
  feature = import ./default.nix args;
in {
  test_programs_dconf_enable = {
    expr = feature.programs.dconf.enable;
    expected = true;
  };
}
