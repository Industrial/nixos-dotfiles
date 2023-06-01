{pkgs, ...}: {
  programs.vscode = {
    enable = true;
    package = pkgs.vscodium;
    enableUpdateCheck = true;
    enableExtensionUpdateCheck = true;
    userSettings = {
      "[haskell]"."editor.defaultFormatter" = "haskell.haskell";
      "[javascript]"."editor.defaultFormatter" = "dbaeumer.vscode-eslint";
      "[javascriptreact]"."editor.defaultFormatter" = "dbaeumer.vscode-eslint";
      "[json]"."editor.defaultFormatter" = "vscode.json-language-features";
      "[jsonc]"."editor.defaultFormatter" = "vscode.json-language-features";
      "[python]"."editor.defaultFormatter" = "ms-python.python";
      "[python]"."editor.formatOnType" = false;
      "[python]"."editor.guides.indentation" = true;
      "[python]"."editor.tabSize" = 4;
      "[ruby]"."editor.defaultFormatter" = "rebornix.ruby";
      "[typescript]"."editor.defaultFormatter" = "dbaeumer.vscode-eslint";
      "[typescriptreact]"."editor.defaultFormatter" = "dbaeumer.vscode-eslint";
      "debug.console.fontSize" = 16;
      "debug.javascript.autoAttachFilter" = "smart";
      "editor.acceptSuggestionOnCommitCharacter" = false;
      "editor.acceptSuggestionOnEnter" = "on";
      "editor.autoClosingBrackets" = "always";
      "editor.autoClosingDelete" = "always";
      "editor.autoClosingQuotes" = "always";
      "editor.codeActionsOnSave"."source.fixAll" = true;
      "editor.defaultFormatter" = "dbaeumer.vscode-eslint";
      "editor.fontFamily" = "'Fira Code', 'FiraCode Nerd Font', 'ProFontWindows Nerd Font', 'Droid Sans Mono', 'monospace', monospace, 'Droid Sans Fallback'";
      "editor.fontLigatures" = true;
      "editor.fontSize" = 16;
      "editor.fontWeight" = "500";
      "editor.formatOnPaste" = true;
      "editor.formatOnSave" = true;
      "editor.gotoLocation.multipleDeclarations" = "gotoAndPeek";
      "editor.gotoLocation.multipleDefinitions" = "gotoAndPeek";
      "editor.gotoLocation.multipleImplementations" = "gotoAndPeek";
      "editor.gotoLocation.multipleReferences" = "gotoAndPeek";
      "editor.gotoLocation.multipleTypeDefinitions" = "gotoAndPeek";
      "editor.inlineSuggest.enabled" = true;
      "editor.largeFileOptimizations" = false;
      "editor.quickSuggestions"."comments" = "on";
      "editor.quickSuggestions"."other" = "on";
      "editor.quickSuggestions"."strings" = "on";
      "editor.quickSuggestionsDelay" = 10;
      "editor.snippetSuggestions" = "top";
      "editor.suggest.filterGraceful" = true;
      "editor.suggest.insertMode" = "insert";
      "editor.suggest.localityBonus" = false;
      "editor.suggest.matchOnWordStartOnly" = true;
      "editor.suggest.preview" = true;
      "editor.suggest.shareSuggestSelections" = true;
      "editor.suggest.showClasses" = true;
      "editor.suggest.showColors" = true;
      "editor.suggest.showConstants" = true;
      "editor.suggest.showConstructors" = true;
      "editor.suggest.showCustomcolors" = true;
      "editor.suggest.showDeprecated" = true;
      "editor.suggest.showEnumMembers" = true;
      "editor.suggest.showEnums" = true;
      "editor.suggest.showEvents" = true;
      "editor.suggest.showFields" = true;
      "editor.suggest.showFiles" = true;
      "editor.suggest.showFolders" = true;
      "editor.suggest.showFunctions" = true;
      "editor.suggest.showIcons" = true;
      "editor.suggest.showInlineDetails" = true;
      "editor.suggest.showInterfaces" = true;
      "editor.suggest.showIssues" = true;
      "editor.suggest.showKeywords" = true;
      "editor.suggest.showMethods" = true;
      "editor.suggest.showModules" = true;
      "editor.suggest.showOperators" = true;
      "editor.suggest.showProperties" = true;
      "editor.suggest.showReferences" = true;
      "editor.suggest.showSnippets" = true;
      "editor.suggest.showStatusBar" = true;
      "editor.suggest.showStructs" = true;
      "editor.suggest.showTypeParameters" = true;
      "editor.suggest.showUnits" = true;
      "editor.suggest.showUsers" = true;
      "editor.suggest.showValues" = true;
      "editor.suggest.showVariables" = true;
      "editor.suggest.showWords" = true;
      "editor.suggest.snippetsPreventQuickSuggestions" = true;
      "editor.suggestOnTriggerCharacters" = true;
      "editor.suggestSelection" = "first";
      "editor.tabSize" = 2;
      "editor.wordBasedSuggestions" = true;
      "emmet.includeLanguages" = {};
      "emmet.showAbbreviationSuggestions" = false;
      "emmet.showExpandedAbbreviation" = "never";
      "emmet.showSuggestionsAsSnippets" = true;
      "eslint.enable" = true;
      "eslint.format.enable" = true;
      "eslint.lintTask.enable" = true;
      "eslint.trace.server" = "verbose";
      "eslint.validate" = ["javascript" "javascriptreact" "json" "jsonc" "typescript" "typescriptreact"];
      "explorer.confirmDelete" = false;
      "explorer.confirmDragAndDrop" = false;
      "extensions.experimental.affinity"."asvetliakov.vscode-neovim" = 1;
      "files.watcherExclude"."**/.git/objects/**" = true;
      "files.watcherExclude"."**/.git/subtree-cache/**" = true;
      "files.watcherExclude"."**/.hg/store/**" = true;
      "files.watcherExclude"."**/node_modules/*/**" = true;
      "git.autofetch" = true;
      "git.confirmSync" = false;
      "git.enableSmartCommit" = true;
      "http.proxyStrictSSL" = false;
      "javascript.updateImportsOnFileMove.enabled" = "always";
      "jupyter.askForKernelRestart" = false;
      "markdown.preview.fontSize" = 16;
      "python.experiments.enabled" = true;
      "python.formatting.blackArgs" = ["-l 180"];
      "python.formatting.provider" = "black";
      "python.linting.enabled" = true;
      "python.linting.flake8Args" = ["--ignore" "E501,W503,W504"];
      "python.linting.flake8Enabled" = true;
      "python.linting.mypyEnabled" = false;
      "references.preferredLocation" = "view";
      #"ruby.format" = "rubocop";
      "ruby.useBundler" = false;
      "ruby.useLanguageServer" = false;
      "rubyLsp.enableExperimentalFeatures" = true;
      "rubyLsp.enabledFeatures" = {
        "codeActions" = true;
        "codeLens" = true;
        "completion" = true;
        "diagnostics" = true;
        "documentHighlights" = true;
        "documentLink" = true;
        "documentSymbols" = true;
        "foldingRanges" = true;
        "formatting" = true;
        "hover" = true;
        "inlayHint" = true;
        "onTypeFormatting" = true;
        "selectionRanges" = true;
        "semanticHighlighting" = true;
      };
      "scm.inputFontSize" = 16;
      "security.workspace.trust.untrustedFiles" = "open";
      "tabnine.experimentalAutoImports" = true;
      "terminal.integrated.copyOnSelection" = true;
      "terminal.integrated.enableMultiLinePasteWarning" = false;
      "terminal.integrated.fontSize" = 16;
      "terminal.integrated.tabs.enableAnimation" = true;
      "terminal.integrated.tabs.enabled" = true;
      "terminal.integrated.tabs.focusMode" = "singleClick";
      "terminal.integrated.tabs.hideCondition" = "never";
      "terminal.integrated.tabs.location" = "left";
      "terminal.integrated.tabs.showActions" = "always";
      "terminal.integrated.tabs.showActiveTerminal" = "always";
      "testExplorer.onReload" = "reset";
      "testExplorer.showOnRun" = true;
      "typescript.updateImportsOnFileMove.enabled" = "always";
      "vim.foldfix" = true;
      "vim.hlsearch" = true;
      "window.autoDetectColorScheme" = true;
      "window.zoomLevel" = 2;
      "workbench.colorTheme" = "Base16 Light Tomorrow";
      "workbench.editor.enablePreview" = false;
      "workbench.enableExperiments" = true;
      "workbench.iconTheme" = "material-icon-theme";
      "workbench.list.openMode" = "doubleClick";
      "workbench.startupEditor" = "none";

      # "whichkey.bindingOverrides" = [
      #   {
      #     "keys" = "/";
      #     "name" = "Comment";
      #     "type" = "command";
      #     "command" = "editor.action.commentLine"
      #   };
      #   {
      #     "keys" = " ";
      #     "name" = "+EasyMotion";
      #     "type" = "bindings";
      #     "bindings" = [
      #       {
      #         "key" = "f";
      #         "name" = "Find {char} to the right";
      #         "type" = "command";
      #         "command" = "vscode-neovim.send";
      #         "args" = "<plug>(easymotion-prefix)f"
      #       };
      #       {
      #         "key" = "F";
      #         "name" = "Find {char} to the right";
      #         "type" = "command";
      #         "command" = "vscode-neovim.send";
      #         "args" = "<plug>(easymotion-prefix)f"
      #       };
      #       {
      #         "key" = "t";
      #         "name" = "till before the {char} to the right";
      #         "type" = "command";
      #         "command" = "vscode-neovim.send";
      #         "args" = "<plug>(easymotion-prefix)t"
      #       };
      #       {
      #         "key" = "T";
      #         "name" = "till after the {char} to the left";
      #         "type" = "command";
      #         "command" = "vscode-neovim.send";
      #         "args" = "<plug>(easymotion-prefix)T"
      #       };
      #       {
      #         "key" = "w";
      #         "name" = "beginning of word forward";
      #         "type" = "command";
      #         "command" = "vscode-neovim.send";
      #         "args" = "<plug>(easymotion-prefix)w"
      #       };
      #       {
      #         "key" = "W";
      #         "name" = "beginning of WORD forward";
      #         "type" = "command";
      #         "command" = "vscode-neovim.send";
      #         "args" = "<plug>(easymotion-prefix)W"
      #       };
      #       {
      #         "key" = "b";
      #         "name" = "beginning of word backward";
      #         "type" = "command";
      #         "command" = "vscode-neovim.send";
      #         "args" = "<plug>(easymotion-prefix)b"
      #       };
      #       {
      #         "key" = "B";
      #         "name" = "beginning of WORD backward";
      #         "type" = "command";
      #         "command" = "vscode-neovim.send";
      #         "args" = "<plug>(easymotion-prefix)B"
      #       };
      #       {
      #         "key" = "e";
      #         "name" = "end of word forward";
      #         "type" = "command";
      #         "command" = "vscode-neovim.send";
      #         "args" = "<plug>(easymotion-prefix)e"
      #       };
      #       {
      #         "key" = "E";
      #         "name" = "end of WORD forward";
      #         "type" = "command";
      #         "command" = "vscode-neovim.send";
      #         "args" = "<plug>(easymotion-prefix)E"
      #       };
      #       {
      #         "key" = "g";
      #         "name" = "+Backwards";
      #         "type" = "bindings";
      #         "bindings" = [
      #           {
      #             "key" = "e";
      #             "name" = "end of word backward";
      #             "type" = "command";
      #             "command" = "vscode-neovim.send";
      #             "args" = "<plug>(easymotion-prefix)ge"
      #           };
      #           {
      #             "key" = "E";
      #             "name" = "end of WORD backward";
      #             "type" = "command";
      #             "command" = "vscode-neovim.send";
      #             "args" = "<plug>(easymotion-prefix)gE"
      #           };
      #         ]
      #       };
      #       {
      #         "key" = "j";
      #         "name" = "line downward";
      #         "type" = "command";
      #         "command" = "vscode-neovim.send";
      #         "args" = "<plug>(easymotion-prefix)j"
      #       };
      #       {
      #         "key" = "k";
      #         "name" = "line upward";
      #         "type" = "command";
      #         "command" = "vscode-neovim.send";
      #         "args" = "<plug>(easymotion-prefix)k"
      #       };
      #       {
      #         "key" = "n";
      #         "name" = "jump to latest '/' or '?' forward";
      #         "type" = "command";
      #         "command" = "vscode-neovim.send";
      #         "args" = "<plug>(easymotion-prefix)n"
      #       };
      #       {
      #         "key" = "N";
      #         "name" = "jump to latest '/' or '?' backward";
      #         "type" = "command";
      #         "command" = "vscode-neovim.send";
      #         "args" = "<plug>(easymotion-prefix)N"
      #       };
      #       {
      #         "key" = "s";
      #         "name" = "find(search) {char} forward and backward";
      #         "type" = "command";
      #         "command" = "vscode-neovim.send";
      #         "args" = "<plug>(easymotion-prefix)s"
      #       }
      #     ]
      #   }
      # ];
    };
    keybindings = [
      {
        key = "ctrl+tab";
        command = "-workbench.action.quickOpenPreviousRecentlyUsedEditorInGroup";
      }
      {
        key = "ctrl+tab";
        command = "workbench.action.nextEditor";
      }
      {
        key = "ctrl+pagedown";
        command = "-workbench.action.nextEditor";
      }
      {
        key = "ctrl+shift+tab";
        command = "workbench.action.previousEditor";
      }
      {
        key = "ctrl+pageup";
        command = "-workbench.action.previousEditor";
      }
      {
        key = "ctrl+shift+tab";
        command = "-workbench.action.quickOpenLeastRecentlyUsedEditorInGroup";
      }
      {
        key = "ctrl+shift+k";
        command = "editor.action.showHover";
        when = "editorTextFocus";
      }
      {
        key = "ctrl+h";
        command = "workbench.action.navigateLeft";
      }
      {
        key = "ctrl+l";
        command = "workbench.action.navigateRight";
      }
      {
        key = "ctrl+k";
        command = "workbench.action.navigateUp";
      }
      {
        key = "ctrl+j";
        command = "workbench.action.navigateDown";
      }
      {
        key = "alt+enter";
        command = "editor.action.inlineSuggest.trigger";
      }
      {
        key = "ctrl+l";
        command = "workbench.action.navigateRight";
      }
      {
        key = "ctrl+enter";
        command = "editor.action.inlineSuggest.trigger";
      }
      {
        key = "ctrl+]";
        command = "editor.action.inlineSuggest.showNext";
      }
      {
        key = "ctrl+[";
        command = "editor.action.inlineSuggest.showPrevious";
      }
    ];

    extensions = with pkgs.vscode-extensions; [
      # Themes
      zhuangtongfa.material-theme
      pkief.material-icon-theme

      # Vim
      vscodevim.vim
      # asvetliakov.vscode-neovim

      # Visual Feedback
      usernamehw.errorlens
      vspacecode.whichkey

      # Remote Development
      (pkgs.vscode-utils.buildVscodeMarketplaceExtension {
        mktplcRef = {
          name = "vscode-remote-extensionpack";
          publisher = "ms-vscode-remote";
          version = "0.24.0";
          sha256 = "sha256-6v4JWpyMxqTDIjEOL3w25bdTN+3VPFH7HdaSbgIlCmo=";
        };
      })

      # Completion
      tabnine.tabnine-vscode

      # File Types
      ## GraphQL
      graphql.vscode-graphql
      ## Markdown
      yzhang.markdown-all-in-one
      # JavaScript / TypeScript
      dbaeumer.vscode-eslint
      denoland.vscode-deno
      # Python
      #ms-python.python
      ms-pyright.pyright
      tamasfe.even-better-toml
      # Nix
      bbenoist.nix
      jnoortheen.nix-ide
      # YAML
      redhat.vscode-yaml
      # Docker
      ms-azuretools.vscode-docker
      # Dotenv
      mikestead.dotenv
      # Git
      mhutchie.git-graph
      (pkgs.vscode-utils.buildVscodeMarketplaceExtension {
        mktplcRef = {
          name = "vscode-git-extension-pack";
          publisher = "sugatoray";
          version = "1.1.1";
          sha256 = "sha256-0b1H5mzhBkf4By67rF3xZXRkfzoNYlvoYCGG+F7Kans=";
        };
      })
      # Ruby
      rebornix.ruby
      (pkgs.vscode-utils.buildVscodeMarketplaceExtension {
        mktplcRef = {
          name = "solargraph";
          publisher = "castwide";
          version = "0.24.0";
          sha256 = "sha256-7mMzN+OdJ5R9CVaBJMzW218wMG5ETvNrUTST9/kjjV0=";
        };
      })
      # Haskell
      haskell.haskell
      (pkgs.vscode-utils.buildVscodeMarketplaceExtension {
        mktplcRef = {
          name = "vscode-ghc-simple";
          publisher = "dramforever";
          version = "0.2.3";
          sha256 = "sha256-dxp7Av3WuUOjJPXNeHTbHQclqwe8epUquvWx3Tq5p90=";
        };
      })
      (pkgs.vscode-utils.buildVscodeMarketplaceExtension {
        mktplcRef = {
          name = "haskell-ghcid";
          publisher = "ndmitchell";
          version = "0.3.1";
          sha256 = "sha256-Ke7P8EJ3ghYG1qyf+w8c2xJlGrRGkJgJwvt0MSb9O+Y=";
        };
      })

      # TODO: Download Error
      #(pkgs.vscode-utils.buildVscodeMarketplaceExtension {
      #  mktplcRef = {
      #    name = "alejandra";
      #    publisher = "kamadorueda";
      #    version = "1.4.0";
      #    sha256 = "sha256-mLgXO0wiG2/UWP5ynV1eboLfH3yoJVBM3T2vU+Dx084=";
      #  };
      #})
      # Testing
      # TODO: Download Error
      #(pkgs.vscode-utils.buildVscodeMarketplaceExtension {
      #  mktplcRef = {
      #    name = "test-adapter-converter";
      #    publisher = "hbenl";
      #    version = "0.1.6";
      #    sha256 = "sha256-fHyePd8fYPt7zPHBGiVmd8fRx+IM3/cSBCyiI/C0VAg=";
      #  };
      #})
      # TODO: These depend on the package above
      #(pkgs.vscode-utils.buildVscodeMarketplaceExtension {
      #  mktplcRef = {
      #    name = "vscode-test-explorer";
      #    publisher = "hbenl";
      #    version = "2.21.1";
      #    sha256 = "sha256-fHyePd8fYPt7zPHBGiVmd8fRx+IM3/cSBCyiI/C0VAg=";
      #  };
      #})
      #(pkgs.vscode-utils.buildVscodeMarketplaceExtension {
      #  mktplcRef = {
      #    name = "vscode-jest-test-adapter";
      #    publisher = "kavod-io";
      #    version = "0.8.1";
      #    sha256 = "sha256-feTCcC3Ts+JsGFngVZll61vl5hOMbPQ2mbmno13zRg8=";
      #  };
      #})
      #(pkgs.vscode-utils.buildVscodeMarketplaceExtension {
      #  mktplcRef = {
      #    name = "playwright";
      #    publisher = "ms-playwright";
      #    version = "1.0.7";
      #    sha256 = "sha256-hCSgMb9kdZu9fK+2G+oM6vWzISb37jFtr33Q3KynRy4=";
      #  };
      #})
    ];
  };

  home.packages = with pkgs; [
    rubyPackages.solargraph

    ghc
    haskellPackages.haskell-language-server
  ];
}
