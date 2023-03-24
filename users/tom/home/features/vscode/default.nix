{
  pkgs,
  config,
  lib,
  ...
}: {
  programs.vscode = {
    enable = true;
    package = pkgs.vscodium;
    enableUpdateCheck = true;
    enableExtensionUpdateCheck = true;
    userSettings = {
      "[javascript]"."editor.defaultFormatter" = "dbaeumer.vscode-eslint";
      "[javascriptreact]"."editor.defaultFormatter" = "dbaeumer.vscode-eslint";
      "[json]"."editor.defaultFormatter" = "vscode.json-language-features";
      "[jsonc]"."editor.defaultFormatter" = "vscode.json-language-features";
      "[python]"."editor.defaultFormatter" = "ms-python.python";
      "[python]"."editor.guides.indentation" = true;
      "[python]"."editor.tabSize" = 4;
      "[typescript]"."editor.defaultFormatter" = "dbaeumer.vscode-eslint";
      "[typescriptreact]"."editor.defaultFormatter" = "dbaeumer.vscode-eslint";
      "debug.console.fontSize" = 16;
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
      "editor.quickSuggestions"."other" = "on";
      "editor.quickSuggestions"."comments" = "on";
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
      "eslint.validate" = [
        "javascript"
        "javascriptreact"
        "json"
        "jsonc"
        "typescript"
        "typescriptreact"
      ];
      "explorer.confirmDelete" = false;
      "explorer.confirmDragAndDrop" = false;
      "extensions.experimental.affinity"."asvetliakov.vscode-neovim" = 1;
      "files.watcherExclude"."**/.git/objects/**" = true;
      "files.watcherExclude"."**/.git/subtree-cache/**" = true;
      "files.watcherExclude"."**/node_modules/*/**" = true;
      "files.watcherExclude"."**/.hg/store/**" = true;
      "git.autofetch" = true;
      "git.confirmSync" = false;
      "git.enableSmartCommit" = true;
      "github.copilit.enable"."*" = true;
      "github.copilit.enable"."yaml" = false;
      "github.copilit.enable"."plaintext" = false;
      "github.copilit.enable"."markdown" = true;
      "github.copilot.inlineSuggest.enable" = true;
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
      "python.linting.mypyEnabled" = true;
      "references.preferredLocation" = "view";
      "scm.inputFontSize" = 16;
      "security.workspace.trust.untrustedFiles" = "open";
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
        key = "ctrl+shift+enter";
        command = "github.copilot.generate";
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
    extensions = [
      # Editing
      (pkgs.vscode-utils.buildVscodeMarketplaceExtension {
        mktplcRef = {
          name = "vim";
          publisher = "vscodevim";
          version = "1.24.3";
          sha256 = "sha256-4fPoRBttWVE8Z3e4O6Yrkf04iOu9ElspQFP57HOPVAk=";
        };
      })

      # Visual Information
      (pkgs.vscode-utils.buildVscodeMarketplaceExtension {
        mktplcRef = {
          name = "errorlens";
          publisher = "usernamehw";
          version = "3.7.0";
          sha256 = "sha256-/+bkVFI5dJo8shmJlRu+Ms3SVGsWi5g1T1V86p3Mk1U=";
        };
      })

      # Auto Completion
      (pkgs.vscode-utils.buildVscodeMarketplaceExtension {
        mktplcRef = {
          name = "vscode-chatgpt";
          publisher = "gencay";
          version = "3.9.2";
          sha256 = "sha256-OJk3bp8Pnt/9JD2Ezlp09G7CNoyYbZu6uCc0/eaCTCo=";
        };
      })

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

      # File Types
      (pkgs.vscode-utils.buildVscodeMarketplaceExtension {
        mktplcRef = {
          name = "vscode-graphql";
          publisher = "GraphQL";
          version = "0.3.53";
          sha256 = "sha256-zEjtAXFGEjB7d1EaHddiusSIQCnai7Pc6oTbY+RE1kM=";
        };
      })

      # JavaScript / TypeScript
      (pkgs.vscode-utils.buildVscodeMarketplaceExtension {
        mktplcRef = {
          name = "vscode-eslint";
          publisher = "dbaeumer";
          version = "2.4.0";
          sha256 = "sha256-7MUQJkLPOF3oO0kpmfP3bWbS3aT7J0RF7f74LW55BQs=";
        };
      })
      (pkgs.vscode-utils.buildVscodeMarketplaceExtension {
        mktplcRef = {
          name = "astro-vscode";
          publisher = "astro-build";
          version = "0.28.0";
          sha256 = "sha256-ff4VcgLtaDu8pM2Y+HvvJRxcgsy78T2CILarUMqyuJ0=";
        };
      })
      (pkgs.vscode-utils.buildVscodeMarketplaceExtension {
        mktplcRef = {
          name = "material-icon-theme";
          publisher = "PKief";
          version = "4.24.0";
          sha256 = "sha256-hJy+ymnlF9a2vvN/HhJ5N75lIc2afzkq+S0Cv/KnD3M=";
        };
      })
      (pkgs.vscode-utils.buildVscodeMarketplaceExtension {
        mktplcRef = {
          name = "bracket-pair-colorizer-2";
          publisher = "CoenraadS";
          version = "0.1.4";
          sha256 = "sha256-YHylV6OHt5W/2jprD5ukNLzfedQwRHLOya2saHDmSiM=";
        };
      })

      # Python
      (pkgs.vscode-utils.buildVscodeMarketplaceExtension {
        mktplcRef = {
          name = "python";
          publisher = "ms-python";
          version = "2023.2.0";
          sha256 = "sha256-By36L9SqsGPtJa9WqO+MdAZVzMnGqkSnu4DcquugmbI=";
        };
      })
      (pkgs.vscode-utils.buildVscodeMarketplaceExtension {
        mktplcRef = {
          name = "pyright";
          publisher = "ms-pyright";
          version = "1.1.294";
          sha256 = "sha256-mLgXO0wiG2/UWP5ynV1eboLfH3yoJVBM3T2vU+Dx084=";
        };
      })
      (pkgs.vscode-utils.buildVscodeMarketplaceExtension {
        mktplcRef = {
          name = "even-better-toml";
          publisher = "tamasfe";
          version = "0.19.0";
          sha256 = "sha256-MqSQarNThbEf1wHDTf1yA46JMhWJN46b08c7tV6+1nU=";
        };
      })

      # Nix
      (pkgs.vscode-utils.buildVscodeMarketplaceExtension {
        mktplcRef = {
          name = "Nix";
          publisher = "bbenoist";
          version = "1.0.1";
          sha256 = "sha256-qwxqOGublQeVP2qrLF94ndX/Be9oZOn+ZMCFX1yyoH0=";
        };
      })
      (pkgs.vscode-utils.buildVscodeMarketplaceExtension {
        mktplcRef = {
          name = "nix-ide";
          publisher = "jnoortheen";
          version = "0.2.1";
          sha256 = "sha256-yC4ybThMFA2ncGhp8BYD7IrwYiDU3226hewsRvJYKy4=";
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
    ];
  };
}
