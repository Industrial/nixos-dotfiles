{lib,...}: {
  programs.nixvim.colorschemes = {
    base16 = {
      enable = true;
      colorscheme = lib.mkDefault "equilibrium-gray-dark";
    };
  };

  # vim.g.base16colorspace = 256
  programs.nixvim.opts.termguicolors = true;
}