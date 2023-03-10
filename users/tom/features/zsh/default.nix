{
  pkgs,
  config,
  ...
}: {
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
        name = "H??vam??l";
        src = pkgs.fetchgit {
          url = "https://github.com/Industrial/havamal-bash";
          rev = "v0.2.0";
          sha256 = "sha256-ikltDhriLYw0nsr4BcpKaEu2iRYSNuEtHeOtX30EzC4=";
        };
      }
    ];
  };
}
