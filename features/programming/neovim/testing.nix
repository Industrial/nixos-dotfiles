{...}: {
  # TODO: https://github.com/nix-community/nixvim/tree/main/plugins/neotest
  # TODO: Check this out. I want coverage to show when I am running tests probably.
  programs.nixvim.plugins.coverage = {
    enable = true;
  };
}
