{pkgs, ...}: let
  module = import ./default.nix {pkgs = pkgs;};
in {
  # Test that lazygit is enabled
  testLazygitEnabled = {
    expr = module.programs.lazygit.enable;
    expected = true;
  };

  # Test that git log settings are configured correctly
  testGitLogSettings = {
    expr = module.programs.lazygit.settings.git.log.showWholeGraph;
    expected = true;
  };
}
