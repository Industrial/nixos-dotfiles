# Fish Plugins, not installable with home manager.
{
  settings,
  pkgs,
  ...
}: let
  havamalPlugin = pkgs.callPackage ./havamal.nix {inherit settings pkgs;};
in {
  environment.etc."fish/config.fish".text = ''
    # Disable greeting
    function fish_greeting
    end

    # Enable Fish plugins
    source ${havamalPlugin}/share/fish/vendor_conf.d/Hávamál.fish

    # Shell abbreviations
    alias dc='docker-compose'
    alias dcl='docker-compose logs'
    alias g='git'
    alias n='npm'
    alias p='pnpm'
    alias y='yarn'
    alias z='zellij --session system'
    alias za='zellij attach system'

    # Variables
    set -x EDITOR "nvim"
    set -x GIT_EDITOR "nvim"
    set -x DIFFPROG "nvim -d"
    set -x XDG_CACHE_HOME "$HOME/.cache"
    set -x XDG_CONFIG_HOME "$HOME/.config"
    set -x XDG_DATA_HOME "$HOME/.local/share"
    set -x XDG_STATE_HOME "$HOME/.local/state"

    # PATH
    fish_add_path $HOME/.bin

    # Terminal CheatSheet
    function cheatsheet
      curl "cheat.sh/$argv"
    end

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
    /run/current-system/sw/bin/direnv hook fish | source

    # Starship Shell
    starship init fish | source
  '';

  # Add condition for darwin system
  system.activationScripts.shellInit.text = pkgs.lib.optionalString (pkgs.system == "aarch64-darwin") ''
    defaults write -g ApplePressAndHoldEnabled -bool false
    defaults write -g AppleInterfaceStyle Dark
    defaults write -g KeyRepeat -int 2
    defaults write -g InitialKeyRepeat -int 15
    defaults write -g AppleShowAllFiles -bool true
    defaults write -g NSAutomaticQuoteSubstitutionEnabled -bool false
    defaults write -g NSAutomaticQuoteSubstitutionEnabled -bool false
    defaults write -g com.apple.gamed Disabled -bool true
  '';
}
