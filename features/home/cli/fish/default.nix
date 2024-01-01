{
  settings,
  pkgs,
  ...
}: let
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
    {
      name = "Hávamál";
      src = havamalPlugin.src;
    }
  ];

  programs.fish.shellAbbrs = {
    dc = "docker-compose";
    dcl = "docker-compose logs";
    g = "git";
    n = "npm";
    p = "pnpm";
    #ta = "tmux attach -t";
    y = "yarn";
    z = "zellij --session system";
    za = "zellij attach system";
  };

  programs.fish.shellInit = ''
    # PATH
    fish_add_path $HOME/.bin
    ${
      if pkgs.system == "darwin"
      then ''fish_add_path /opt/homebrew/bin''
      else ""
    }

    # Replacement for cat
    function cat --wraps bat
      bat $argv
    end

    # Replacement for du
    function du --wraps dust
      dust $argv
    end

    # CD alias
    function c
      cd $argv
      l
    end

    # Clear alias
    function cl
      clear
    end

    # LS alias
    function l
      eza \
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

    # LS alias (no hidden files)
    function ll
      eza \
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

    # OSX Settings
    ${
      if pkgs.system == "darwin"
      then ''
        defaults write -g ApplePressAndHoldEnabled -bool false
        defaults write -g AppleInterfaceStyle Dark
        defaults write -g KeyRepeat -int 2
        defaults write -g InitialKeyRepeat -int 15
        defaults write -g AppleShowAllFiles -bool true
        defaults write -g NSAutomaticQuoteSubstitutionEnabled -bool false
        defaults write -g NSAutomaticQuoteSubstitutionEnabled -bool false
        defaults write -g com.apple.gamed Disabled -bool true
      ''
      else ""
    }
  '';

  programs.fish.interactiveShellInit = ''
    # Disable greeting
    function fish_greeting
    end
  '';
}
