# TODO: Base16.
# TODO: Powerline-ish thing.
# TODO: Copy ZSH setup.

{environment, pkgs, ...}: {
  home.packages = with pkgs; [
    base16-schemes
    fishPlugins.autopair
    fishPlugins.fzf
    fishPlugins.grc
    fishPlugins.done
    fzf
    grc
  ];
  programs.fish.enable = true;
  programs.fish.plugins = [
    { name = "autopair"; src = pkgs.fishPlugins.autopair.src; }
    { name = "done"; src = pkgs.fishPlugins.done.src; }
    { name = "fzf"; src = pkgs.fishPlugins.fzf.src; }
    { name = "grc"; src = pkgs.fishPlugins.grc.src; }
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
      ls -AFhHlX --color=auto --group-directories-first $argv
    end

    function ll
      ls -FhHlX --color=auto --group-directories-first $argv
    end

    # Use vim keybindings.
    fish_vi_key_bindings

    function fish_user_key_bindings
      bind --user -M insert \cp up-or-search
      bind --user -M insert \cn down-or-search
    end
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