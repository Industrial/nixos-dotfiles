{pkgs, ...}: let
  havamalPlugin = pkgs.callPackage ./havamal.nix {};
in {
  # Enable HomeManager Fish, not system fish.
  programs.fish.enable = true;

  # Make sure the fish plugins and their dependencies are installed in environment.systemPackages.
  programs.fish.plugins = [
    {
      name = "bass";
      src = pkgs.fishPlugins.bass.src;
    }
    {
      name = "fzf";
      src = pkgs.fishPlugins.fzf.src;
    }
    # TODO: Make it only run on interactive shells
    #{
    #  name = "Hávamál";
    #  src = havamalPlugin.src;
    #}
  ];

  programs.fish.shellAbbrs = {
    dc = "docker-compose";
    dcl = "docker-compose logs";
    g = "git";
    n = "npm";
    p = "pnpm";
    ta = "tmux attach -t";
    y = "yarn";
  };

  programs.fish.shellInit = ''
    # Replacement for cat
    function cat --wraps bat
      bat $argv
    end

    # Replacement for du
    function du --wraps dust
      dust $argv
    end

    function c
      cd $argv
      l
    end

    function cl
      clear
      tmux clear-history
      clear
    end

    function l
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
      $argv
    end

    function ll
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
      $argv
    end

    function tmux-sessions
      tmux kill-server

      sleep 1

      tmux new-session -d -s system -n scratch -c "$HOME"

      tmux new-window -a -t system:scratch -n processes -c "$HOME"
      tmux send-keys -t system:processes "htop" Enter
      tmux select-window -t system:processes
      tmux split-window -v "nethogs"

      tmux new-window -a -t system:processes -n configuration -c "$HOME/.dotfiles"
      tmux send-keys -t system:configuration "nvim flake.nix" Enter
      tmux select-window -t system:configuration
      tmux split-window -h
      tmux send-keys -t system:configuration "c $HOME/.dotfiles" Enter

      tmux new-window -a -t system:configuration -n media -c "$HOME"
      tmux send-keys -t system:media "mpv --no-video --loop $HOME/Music/1-minute-of-silence.mp3" Enter
      tmux select-window -t system:media
      tmux split-window -h
      tmux send-keys -t system:media "pulsemixer" Enter

      tmux new-window -a -t system:media -n taskwarrior -c "$HOME"
      tmux send-keys -t system:taskwarrior "vit" Enter

      tmux new-window -a -t system:taskwarrior -n code -c "$HOME/Code/code9"

      tmux attach -t system
    end

    function zellij-sessions
      echo "> zellij kill-all-sessions"
      zellij kill-all-sessions

      echo "> zellij --session system"
      zellij --session system

      echo "> zellij --session system action rename-tab scratch"
      zellij --session system action rename-tab scratch

      echo "> zellij --session system action new-tab --layout vertical --name processes"
      zellij --session system action new-tab --layout vertical --name processes

      echo "> zellij --session system action new-tab --layout vertical --name configuration"
      zellij --session system action new-tab --layout vertical --name configuration

      echo "> zellij --session system action new-tab --layout vertical --name media"
      zellij --session system action new-tab --layout vertical --name media

      echo "> zellij --session system action new-tab --layout vertical --name taskwarrior"
      zellij --session system action new-tab --layout vertical --name taskwarrior

      echo "> zellij --session system action new-tab --layout vertical --name code"
      zellij --session system action new-tab --layout vertical --name code

      echo "> zellij attach system"
      zellij attach system
    end

    # Use vim keybindings.
    fish_vi_key_bindings

    function fish_user_key_bindings
      bind --user -M insert \cp up-or-search
      bind --user -M insert \cn down-or-search
    end

    # Direnv
    direnv hook fish | source

    # Starship Shell
    starship init fish | source
  '';

  programs.fish.interactiveShellInit = ''
    # Disable greeting
    function fish_greeting
    end
  '';
}
