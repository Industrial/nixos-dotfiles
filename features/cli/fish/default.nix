# Fish Plugins, not installable with home manager.
{
  settings,
  pkgs,
  ...
}: let
  havamalPlugin = pkgs.callPackage ./havamal.nix {inherit settings pkgs;};
in {
  programs.fish.enable = true;
  environment.shells = with pkgs; [fish];
  users.users."${settings.username}".shell = pkgs.fish;

  environment.etc."fish/config.fish".text = ''
    # Disable greeting
    function fish_greeting
    end

    # Enable Fish plugins
    source ${havamalPlugin}/share/fish/vendor_conf.d/Hávamál.fish

    # Shell abbreviations
    alias g='git'
    # alias z='zellij --session system'
    # alias za='zellij attach system'

    # # Variables
    # set -x EDITOR "vim"
    # set -x GIT_EDITOR "vim"
    # set -x DIFFPROG "vim -d"
    set -x XDG_CACHE_HOME "$HOME/.cache"
    set -x XDG_CONFIG_HOME "$HOME/.config"
    set -x XDG_DATA_HOME "$HOME/.local/share"
    set -x XDG_STATE_HOME "$HOME/.local/state"
    # TODO: Someone on Discord told me this is a bad idea and I should patch
    #       specific software instead (Continue VSCode Plugin).
    set -x LD_LIBRARY_PATH "${pkgs.stdenv.cc.cc.lib}/lib:$LD_LIBRARY_PATH"

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
    defaults write -g com.apple.gamed Disabled
  '';
}
