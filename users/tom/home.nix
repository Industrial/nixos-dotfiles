{ pkgs, inputs, nixpkgs, config, lib, ... }:

rec {
  #programs.home-manager.enable = true;

  #home.username = "tom";
  #home.homeDirectory = "/home/tom";
  #home.stateVersion = "21.05";

  home.packages = [
    pkgs.bitwarden
    pkgs.bookworm
    pkgs.chromium
    pkgs.direnv
    pkgs.discord
    pkgs.docker-compose
    pkgs.element-desktop
    pkgs.exa
    pkgs.fd
    pkgs.filezilla
    pkgs.firefox
    pkgs.fzf
    pkgs.gcc
    pkgs.gitkraken
    pkgs.gnomeExtensions.material-shell
    pkgs.htop
    pkgs.lutris
    pkgs.meld
    pkgs.nethogs
    pkgs.ripgrep
    pkgs.slack
    pkgs.spotify
    pkgs.starship
    pkgs.steam
    pkgs.transmission-gtk
    pkgs.vit
    pkgs.vlc
    pkgs.xclip
    pkgs.xsel
    pkgs.zeal
    pkgs.yubikey-manager-qt
    pkgs.yubikey-personalization-gui

    # Tor
    pkgs.tor-browser-bundle-bin

    # Python
    pkgs.stdenv.cc.cc.lib
    pkgs.python3
    pkgs.virtualenv
    pkgs.poetry

    # Neovim
    pkgs.luajitPackages.luacheck
    pkgs.nodePackages.bash-language-server
    pkgs.nodePackages.dockerfile-language-server-nodejs
    pkgs.nodePackages.stylelint
    pkgs.nodePackages.typescript-language-server
    pkgs.nodePackages.vim-language-server
    pkgs.nodePackages.vscode-langservers-extracted
    pkgs.nodePackages.yaml-language-server
    pkgs.pyright
    pkgs.python-language-server
    pkgs.sumneko-lua-language-server

    # World of Warcraft
    pkgs.alsa-lib
    pkgs.alsa-plugins
    pkgs.giflib
    pkgs.gnutls
    pkgs.gtk3
    pkgs.libgcrypt
    pkgs.libgpg-error
    pkgs.libjpeg
    pkgs.libnghttp2
    pkgs.libpng
    pkgs.libpulseaudio
    pkgs.libva
    pkgs.libxslt
    pkgs.mpg123
    pkgs.ncurses
    pkgs.ocl-icd
    pkgs.openal
    pkgs.sqlite
    pkgs.v4l-utils
    pkgs.xorg.libXcomposite

  ];

  programs.git = {
    enable = true;
    userName  = "Tom Wieland";
    userEmail = "tom.wieland@gmail.com";
    aliases = {
      a   = "add";
      A   = "add -A";
      aa  = "add -A";
      b   = "branch";
      ba  = "branch --all";
      bd  = "branch -d";
      cb  = "checkout -b";
      cm  = "commit -m";
      co  = "checkout";
      cp  = "cherry-pick";
      cpa = "cherry-pick --abort";
      cpc = "cherry-pick --continue";
      d   = "diff";
      dc  = "diff --cached";
      dt  = "difftool -y";
      dtd = "difftool -y --dir-diff";
      f   = "fetch -p --all";
      l   = "log --oneline --graph --decorate=full";
      la  = "log --all --oneline --graph --decorate=full";
      lg  = "log";
      m   = "merge";
      mt  = "mergetool";
      p   = "pull";
      pa  = "pull -a";
      ps  = "push -u";
      psf = "push -u -f";
      psa = "push origin --all";
      rb  = "rebase";
      rba = "rebase --abort";
      rbc = "rebase --continue";
      rbs = "rebase --skip";
      rbi = "rebase -i";
      rn  = "reset HEAD@{1}";
      rp  = "reset HEAD~1";
      rs  = "reset";
      rsh = "reset --hard HEAD^";
      rss = "reset --soft HEAD^";
      r   = "remote --verbose";
      ru  = "remote update -p";
      s   = "status";
      sh  = "stash";
      t   = "tag";
    };
    extraConfig = {
      init = {
        defaultBranch = "main";
      };

      core = {
        mergeoptions = "--no-edit";
      };

      rebase = {
        autoStash = true;
      };

      pull = {
        ff = true;
        rebase = true;
      };

      push = {
        default = "current";
      };

      diff = {
        tool = "meld";
      };

      difftool = {
        prompt = false;
      };

      merge = {
        tool = "meld";
      };

      github = {
        user = "Industrial";
      };
    };
  };

  programs.zsh = {
    enable = true;
    shellAliases = {};

    initExtra = ''
      # Direnv
      eval "$(direnv hook zsh)"

      # Starship shell
      eval "$(starship init zsh)"

      # Base16 colorschemes
      BASE16_SHELL_PATH="$HOME/.config/base16-shell"
      [ -n "$PS1" ] && \
        [ -s "$BASE16_SHELL_PATH/profile_helper.sh" ] && \
        source "$BASE16_SHELL_PATH/profile_helper.sh"

      export EDITOR=nvim
      export GIT_EDITOR=nvim
      export PAGER=less

      l() {
        exa \
        --colour=always \
        --icons \
        --long \
          --group \
          --header \
          --time-style long-iso \
          --git \
        --classify \
        --group-directories-first \
        --sort Extension \
        --all \
        $1
      }

      ll() {
        exa \
        --colour=always \
        --icons \
        --long \
          --group \
          --header \
          --time-style long-iso \
          --git \
        --classify \
        --group-directories-first \
        --sort Extension \
        $1
      }
      
      c() {
        cd $1 && l
      }

      dc() {
        docker-compose $1
      }

      g() {
        git $1
      }

      n() {
        npm $1
      }

      ta() {
        tmux attach -t $1
      }

      cl() {
        clear
        tmux clear-history
        clear
      }

      tmux-sessions() {
        tmux kill-server

        sleep 1

        tmux new-session -d -s system -n scratch -c "$HOME"

        tmux new-window -a -t system:scratch -n processes -c "$HOME"
        tmux send-keys -t system:processes "htop" Enter
        tmux select-window -t system:processes
        tmux split-window -v "nethogs"

        tmux new-window -a -t system:processes -n configuration -c "$HOME"
        tmux send-keys -t system:configuration "nvim /etc/nixos/configuration.nix" Enter
        tmux select-window -t system:configuration
        tmux split-window -h

        tmux new-window -a -t system:configuration -n taskwarrior -c "$HOME"
        tmux send-keys -t system:taskwarrior "vit" Enter

        tmux new-window -a -t system:taskwarrior -n code -c "$HOME/Code/code9"

        tmux attach -t system
      }
    '';

    plugins = [
      {
        name = "zsh-autosuggestions";
        src = pkgs.fetchFromGitHub {
          owner = "zsh-users";
          repo = "zsh-autosuggestions";
          rev = "v0.7.0";
          sha256 = "sha256-KLUYpUu4DHRumQZ3w59m9aTW6TBKMCXl2UcKi4uMd7w=";
        };
      }
      {
        name = "zsh-vi-mode";
        src = pkgs.fetchFromGitHub {
          owner = "jeffreytse";
          repo = "zsh-vi-mode";
          rev = "v0.9.0";
          sha256 = "sha256-KQ7UKudrpqUwI6gMluDTVN0qKpB15PI5P1YHHCBIlpg=";
        };
      }
      {
        name = "fzf-tab";
        src = pkgs.fetchgit {
          url = "https://github.com/Aloxaf/fzf-tab";
          rev = "ffb7b776be492333b94cf0be87456b62a1f26e2f";
          sha256 = "sha256-bIlnYKjjOC6h5/Gg7xBg+i2TBk+h82wmHgAJPhzMsek=";
        };
      }
      {
        name = "base16-shell";
          src = pkgs.fetchgit {
          url = "https://github.com/tinted-theming/base16-shell";
          rev = "64b96b17fc1d7cb16fb5c64b5dbed7f8b2379f6d";
          sha256 = "sha256-SnvGz5MANQPYZIgIriv3Ly4YcvSpQLwMsZDEO3qwKNI=";
        };
      }
      {
        name = "zsh-fzf-history-search";
        src = pkgs.fetchgit {
          url = "https://github.com/joshskidmore/zsh-fzf-history-search";
          rev = "446da4a412048ae3ea16e5a355f953385d965742";
          sha256 = "sha256-nGwnClIEvs8scQzDBTqCt6gu9PdM3WunGduUq0sQ5BQ=";
        };
      }
      {
        name = "havamal-bash";
        src = pkgs.fetchgit {
          url = "https://github.com/Industrial/havamal-bash";
          rev = "v0.1.0";
          sha256 = "sha256-EewgCobzZtyaO5hAlQ8sttQVclOi35S3tnqz1PxMj1w=";
        };
      }
      {
        name = "communism";
        src = pkgs.fetchgit {
          url = "https://github.com/victoria-riley-barnett/Communism";
          rev = "v1.4";
          sha256 = "sha256-cpJlnNC97fOzecTe1Xl3ZKJQqNKmZ17IugeO5AaEaDE=";
        };
      }
    ];
  };

  programs.tmux = {
    aggressiveResize = false;
    baseIndex = 1;
    clock24 = true;
    customPaneNavigationAndResize = false;
    disableConfirmationPrompt = false;
    enable = true;
    escapeTime = 500;
    extraConfig = ''
      set -g mouse on
      set -g focus-events on
      set-option -sg escape-time 10
    '';
    historyLimit = 99999;
    keyMode = "vi";
    newSession = false;
    package = pkgs.tmux;
    prefix = "C-a";
    resizeAmount = 10;
    reverseSplit = false;
    secureSocket = false;
    sensibleOnTop = true;
    #shell = ${pkgs.zsh}/bin/zsh;
    terminal = "tmux-256color";
    tmuxinator = {
      enable = false;
    };

    plugins = with pkgs; [
      { plugin = tmuxPlugins.yank; }
      { plugin = tmuxPlugins.pain-control; }
    ];
  };

  # environment.variables.EDITOR = "nvim";
  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;

    extraPackages = [
      pkgs.nodejs-16_x
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

  programs.taskwarrior = {
    enable = true;
    config = {
      confirmation = false;
      report.minimal.filter = "status:pending";
      report.active.columns = [ "id" "start" "entry.age" "priority" "project" "due" "description" ];
      report.active.labels  = [ "ID" "Started" "Age" "Priority" "Project" "Due" "Description" ];
      taskd = {
        certificate = "/home/tom/.taskwarrior_certs/default-client.cert.pem";
        key = "/home/tom/.taskwarrior_certs/default-client.key.pem";
        ca = "/home/tom/.taskwarrior_certs/ca.cert.pem";
        server = "server.local:53589";
        credentials = "Default/Default/06eee0ff-b5f3-490f-9f3c-06015f4c8261";
        trust = "ignore hostname";
      };
    };
  };
}
