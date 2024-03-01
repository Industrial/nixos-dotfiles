# TODO: Git diff support
{
  settings,
  pkgs,
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
      nodePackages.purescript-language-server
      nodePackages.purs-tidy
      nodePackages.stylelint
      nodePackages.typescript
      nodePackages.typescript-language-server
      nodePackages.vim-language-server
      nodePackages.vscode-langservers-extracted
      nodePackages.yaml-language-server
      nodejs_20
      purescript
      pyright
      python311Packages.python-lsp-server
      #spago
      statix
      stylua
      sumneko-lua-language-server
      gcc
    ];

    plugins = with pkgs.vimPlugins; [
      base16-vim
      bufferline-nvim
      cmp-buffer
      cmp-cmdline
      cmp-nvim-lsp
      cmp-nvim-lsp-signature-help
      cmp-path
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
      nvim-treesitter.withAllGrammars
      nvim-web-devicons
      plenary-nvim
      purescript-vim
      telescope-dap-nvim
      telescope-nvim
      trouble-nvim
      vim-sleuth
      which-key-nvim
      {
        plugin = nvim-tree-lua;
        config = ''
          packadd nvim-tree.lua
        '';
      }
    ];

    extraConfig = ''
      luafile ${./init.lua}
    '';
  };
}
