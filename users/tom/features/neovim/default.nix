{ pkgs, config, ... }:

{
  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;

    extraPackages = [
      pkgs.nodejs-16_x
      pkgs.nodejs-16_x.pkgs."@astrojs/language-server"
      #pkgs.nodejs-16_x.pkgs."@cucumber/language-server"
      #pkgs.nodejs-16_x.pkgs."@johnnymorganz/stylua-bin"
      pkgs.nodejs-16_x.pkgs.bash-language-server
      #pkgs.nodejs-16_x.pkgs.cssmodules-language-server
      #pkgs.nodejs-16_x.pkgs.dot-language-server
      pkgs.nodejs-16_x.pkgs.eslint
      pkgs.nodejs-16_x.pkgs.eslint_d
      pkgs.nodejs-16_x.pkgs.graphql-language-service-cli
      #pkgs.nodejs-16_x.pkgs.stylelint-lsp
      pkgs.nodejs-16_x.pkgs.typescript
      pkgs.nodejs-16_x.pkgs.typescript-language-server
      pkgs.nodejs-16_x.pkgs.vim-language-server
      pkgs.nodejs-16_x.pkgs.vscode-langservers-extracted
      pkgs.nodejs-16_x.pkgs.yaml-language-server
    ];

    extraConfig = ''
      lua require('initialize')
    '';

    plugins = [
      { plugin = pkgs.vimPlugins.vim-sleuth; }
      { plugin = pkgs.vimPlugins.base16-vim; }
      { plugin = pkgs.vimPlugins.which-key-nvim; }
      { plugin = pkgs.vimPlugins.moonscript-vim; }
      #{ plugin = pkgs.vimPlugins.nvim-moonmaker; }
      { plugin = pkgs.vimPlugins.nvim-web-devicons; }
      {
        plugin = pkgs.vimPlugins.nvim-tree-lua;
        config = ''
          packadd nvim-tree.lua
        '';
      }
      { plugin = pkgs.vimPlugins.nvim-treesitter.withAllGrammars; }
      { plugin = pkgs.vimPlugins.nvim-autopairs; }
      { plugin = pkgs.vimPlugins.lspkind-nvim; }
      { plugin = pkgs.vimPlugins.nvim-cmp; }
      { plugin = pkgs.vimPlugins.nvim-lspconfig; }
      { plugin = pkgs.vimPlugins.cmp-nvim-lsp; }
      { plugin = pkgs.vimPlugins.cmp-nvim-lsp-signature-help; }
      { plugin = pkgs.vimPlugins.cmp-buffer; }
      { plugin = pkgs.vimPlugins.cmp-path; }
      { plugin = pkgs.vimPlugins.cmp-cmdline; }
      { plugin = pkgs.vimPlugins.null-ls-nvim; }
      { plugin = pkgs.vimPlugins.telescope-dap-nvim; }
      { plugin = pkgs.vimPlugins.nvim-dap-ui; }
      { plugin = pkgs.vimPlugins.nvim-dap; }
      { plugin = pkgs.vimPlugins.nvim-dap-python; }
      { plugin = pkgs.vimPlugins.bufferline-nvim; }
      { plugin = pkgs.vimPlugins.nvim-comment; }
      { plugin = pkgs.vimPlugins.trouble-nvim; }
      { plugin = pkgs.vimPlugins.indent-blankline-nvim; }
      { plugin = pkgs.vimPlugins.plenary-nvim; }
      { plugin = pkgs.vimPlugins.telescope-nvim; }
      { plugin = pkgs.vimPlugins.lualine-nvim; }
      { plugin = pkgs.vimPlugins.copilot-vim; }
    ];
  };
}
