{environment, pkgs, ...}:
let
  havamalPlugin = pkgs.callPackage ./havamal.nix { };
in
{
  home.packages = with pkgs; [
    base16-schemes
    exa
    fishPlugins.autopair
    fishPlugins.bass
    fishPlugins.done
    fishPlugins.fzf
    fishPlugins.grc
    fzf
    grc
    starship
  ];
  programs.fish.enable = true;
  programs.fish.plugins = [
    { name = "autopair"; src = pkgs.fishPlugins.autopair.src; }
    { name = "bass"; src = pkgs.fishPlugins.bass.src; }
    { name = "done"; src = pkgs.fishPlugins.done.src; }
    { name = "fzf"; src = pkgs.fishPlugins.fzf.src; }
    { name = "grc"; src = pkgs.fishPlugins.grc.src; }
    { name = "Hávamál"; src = havamalPlugin.src; }
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
      $1
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
      $1
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
      tmux send-keys -t system:configuration "nvim /etc/nixos/configuration.nix" Enter
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

    # Hávamál
  '';

  programs.fish.interactiveShellInit = ''
    # Disable greeting
    set fish_greeting

    # # Base16 Shell
    # set BASE16_SHELL "$HOME/.config/base16-shell/"
    # source "$BASE16_SHELL/profile_helper.fish"

    # # Promptline
    # function fish_prompt
    #   env FISH_VERSION=$FISH_VERSION PROMPTLINE_LAST_EXIT_CODE=$status bash ~/.promptline.sh left
    # end

    # function fish_right_prompt
    #   env FISH_VERSION=$FISH_VERSION PROMPTLINE_LAST_EXIT_CODE=$status bash ~/.promptline.sh right
    # end
  '';
}