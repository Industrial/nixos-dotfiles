# Assay: neovim language support (treesitter, LSP, completion, linters).
#
# Claims read the evaluated nixvim config: the module is evaluated alone on top of the
# nixvim NixOS module. Most LSP servers are set up from Lua, so the generated
# extraConfigLua is the artifact and is matched as text.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  inherit (nixos) lib;
  system = nixos.evalSystem {modules = [nixos.flakeInputs.nixvim.nixosModules.nixvim ./language-support.nix];};
  cfg = system.config;
  nv = cfg.programs.nixvim;
  p = nv.plugins;
  lua = nv.extraConfigLua;
  # Which of `names` are not installed system-wide; [] when all are.
  notInstalled = names: builtins.filter (n: !(nixos.hasPackage cfg n)) names;
  pluginNames = map (x: lib.getName (x.plugin or x)) nv.extraPlugins;
in
  assay.suite "language-support" {
    enablesLint = assay.eq p.lint.enable true;

    enablesTreesitter = assay.eq p.treesitter.enable true;
    treesitterIndents = assay.eq p.treesitter.settings.indent.enable true;
    installsEveryGrammar =
      assay.eq (builtins.length p.treesitter.grammarPackages)
      (builtins.length system.pkgs.vimPlugins.nvim-treesitter.allGrammars);
    enablesTreesitterContext = assay.eq p.treesitter-context.enable true;
    # treesitter-refactor conflicts with the main-branch nvim-treesitter module ("two
    # different versions of nvim-treesitter", nixvim#4188); it must stay off.
    treesitterRefactorStaysOff = assay.eq p.treesitter-refactor.enable false;
    # hmts.nvim 1.3.0 crashes every *.nix buffer on Neovim 0.12's query API.
    hmtsStaysOff = assay.eq p.hmts.enable false;
    enablesRainbowDelimiters = assay.eq p.rainbow-delimiters.enable true;

    enablesNixAndDirenv = assay.eq [p.nix.enable p.direnv.enable] [true true];
    enablesTypeScriptHelpers = assay.eq [p.ts-autotag.enable p.ts-context-commentstring.enable] [true true];

    enablesLsp = assay.eq p.lsp.enable true;
    # rust-analyzer is the one server nixvim manages, with its own toolchain.
    rustAnalyzerWithToolchain = assay.eq {inherit (p.lsp.servers.rust_analyzer) enable installCargo installRustc installRustfmt;} {
      enable = true;
      installCargo = true;
      installRustc = true;
      installRustfmt = true;
    };

    enablesCmp = assay.eq p.cmp.enable true;
    cmpAutoEnablesSources = assay.eq p.cmp.settings.autoEnableSources true;
    cmpSources =
      assay.eq (map (s: s.name) p.cmp.settings.sources)
      ["nvim_lsp" "cmp-clippy" "async_path" "treesitter" "buffer" "cmdline"];

    addsLspconfigAndLspkind = assay.eq (lib.subtractLists pluginNames ["nvim-lspconfig" "lspkind.nvim"]) [];

    # Servers configured from Lua (through lspconfig, or vim.lsp.config as fallback).
    setsUpLuaServers = assay.eq (builtins.filter (s: !(lib.hasInfix "setup_lsp_server('${s}'" lua)) [
      "bashls"
      "cssls"
      "cssmodules_ls"
      "dockerls"
      "dotls"
      "eslint"
      "graphql"
      "html"
      "jsonls"
      "lua_ls"
      "nixd"
      "pylsp"
      "pyright"
      "ts_ls"
      "vimls"
      "yamlls"
    ]) [];
    shiftKHovers = assay.eq (lib.hasInfix ''vim.keymap.set("n", "<S-k>", vim.lsp.buf.hover'' lua) true;
    registersLspMenu = assay.eq (builtins.filter (k: !(lib.hasInfix "{ \"${k}\"" lua)) [
      "<leader>l"
      "<leader>lD"
      "<leader>lR"
      "<leader>la"
      "<leader>ld"
      "<leader>lh"
      "<leader>li"
      "<leader>lk"
      "<leader>lr"
    ]) [];

    installsLanguageServers = assay.eq (notInstalled [
      "lua-language-server"
      "nixd"
      "bash-language-server"
      "dockerfile-language-server"
      "graphql-language-service-cli"
      "typescript-language-server"
      "vim-language-server"
      "vscode-langservers-extracted"
    ]) [];
    installsFormattersAndLinters = assay.eq (notInstalled [
      "stylua"
      "codespell"
      "luacheck"
      "eslint"
      "dprint"
      "ShellCheck"
      "statix"
      "alejandra"
      "vale"
      "autopep8"
      "black"
      "flake8"
      "isort"
    ]) [];
    installsToolchainSupport = assay.eq (notInstalled ["plenary.nvim" "moonscript" "typescript" "tree-sitter"]) [];
  }
