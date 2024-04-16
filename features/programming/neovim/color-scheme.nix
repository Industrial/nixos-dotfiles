{lib,...}: {
  programs.nixvim.colorschemes = {
    base16 = {
      enable = true;
      colorscheme = lib.mkDefault "gruvbox-dark-medium";
    };
  };

  # vim.g.base16colorspace = 256
  programs.nixvim.opts.termguicolors = true;
}
