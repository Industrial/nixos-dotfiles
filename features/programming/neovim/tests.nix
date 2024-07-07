args @ {pkgs, ...}: let
  feature = import ./default.nix args;
in {
  test_programs_nixvim_enable = {
    expr = feature.programs.nixvim.enable;
    expected = true;
  };
  test_programs_nixvim_globals = {
    expr = feature.programs.nixvim.globals;
    expected = {
      loaded_netrw = 1;
      loaded_netrwPlugin = 1;

      mapleader = " ";
    };
  };
  test_environment_systemPackages_xsel = {
    expr = builtins.elem pkgs.xsel feature.environment.systemPackages;
    expected = true;
  };
  test_environment_systemPackages_xclip = {
    expr = builtins.elem pkgs.xclip feature.environment.systemPackages;
    expected = true;
  };
}
