{pkgs, ...}: {
  programs = {
    nixvim = {
      plugins = {
        # Mini (https://github.com/echasnovski/mini.nvim)
        mini = {
          enable = true;
        };
      };
    };
  };
}
