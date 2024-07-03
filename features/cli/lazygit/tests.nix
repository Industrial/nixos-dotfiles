{
  inputs,
  settings,
  pkgs,
  ...
}: let
  feature = import ./default.nix {inherit inputs pkgs settings;};
in {
  test_programs = {
    expr = feature.programs.lazygit.enable;
    expected = true;
  };

  test_settings = {
    expr = feature.programs.lazygit.settings.git.log.showWholeGraph;
    expected = true;
  };
}
