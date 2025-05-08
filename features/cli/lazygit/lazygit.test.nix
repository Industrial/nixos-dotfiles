{pkgs, ...}: let
  lazygitModule = import ./default.nix {pkgs = pkgs;};
in {
  # Test that lazygit is enabled
  testLazygitEnabled = {
    expr = lazygitModule.programs.lazygit.enable;
    expected = true;
  };

  # Test that git log settings are configured correctly
  testGitLogSettings = {
    expr = lazygitModule.programs.lazygit.settings.git.log.showWholeGraph;
    expected = true;
  };
}
