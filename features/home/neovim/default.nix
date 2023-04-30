{
  pkgs,
  lib,
  config,
  ...
}: {
  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;

    extraPackages = with pkgs; [
      alejandra
      luajitPackages.luacheck
      nil
      nixfmt
      nodePackages."@astrojs/language-server"
      nodePackages.bash-language-server
      nodePackages.dockerfile-language-server-nodejs
      nodePackages.eslint
      nodePackages.eslint_d
      nodePackages.graphql-language-service-cli
      nodePackages.stylelint
      nodePackages.typescript
      nodePackages.typescript-language-server
      nodePackages.vim-language-server
      nodePackages.vscode-langservers-extracted
      nodePackages.yaml-language-server
      nodejs-16_x
      pyright
      python311Packages.python-lsp-server
      stylua
      sumneko-lua-language-server
    ];

    extraConfig = ''
      lua require('initialize')
    '';

    plugins = with pkgs.vimPlugins; [
      base16-vim
      bufferline-nvim
      cmp-buffer
      cmp-cmdline
      cmp-nvim-lsp
      cmp-nvim-lsp-signature-help
      cmp-path
      copilot-vim
      indent-blankline-nvim
      lspkind-nvim
      lualine-nvim
      moonscript-vim
      null-ls-nvim
      nvim-autopairs
      nvim-cmp
      nvim-comment
      nvim-dap
      nvim-dap-python
      nvim-dap-ui
      nvim-lspconfig
      {
        plugin = nvim-tree-lua;
        config = ''
          packadd nvim-tree.lua
        '';
      }
      nvim-treesitter.withAllGrammars
      nvim-web-devicons
      plenary-nvim
      telescope-dap-nvim
      telescope-nvim
      trouble-nvim
      which-key-nvim
      vim-sleuth
    ];
  };
}
