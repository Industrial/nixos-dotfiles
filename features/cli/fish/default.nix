{
  settings,
  pkgs,
  ...
}: let
  havamalPlugin = pkgs.callPackage ./havamal.nix {inherit settings pkgs;};
in {
  programs = {
    fish = {
      enable = true;
    };
  };
  environment = {
    shells = with pkgs; [
      fish
    ];
    etc = {
      "fish/config.fish" = {
        text = ''
          # Disable greeting
          function fish_greeting
          end

          # Enable Fish plugins
          source ${havamalPlugin}/share/fish/vendor_conf.d/Hávamál.fish

          # Variables
          # set -x EDITOR "vim"
          # set -x GIT_EDITOR "vim"
          # set -x DIFFPROG "vim -d"
          set -x XDG_CACHE_HOME "$HOME/.cache"
          set -x XDG_CONFIG_HOME "$HOME/.config"
          set -x XDG_DATA_HOME "$HOME/.local/share"
          set -x XDG_STATE_HOME "$HOME/.local/state"

          # Use vim keybindings.
          fish_vi_key_bindings

          # Remove default aliases.
          functions -e l
          functions -e ll
          functions -e ls

          # Keybindings
          function fish_user_key_bindings
            bind --user -M insert \cp up-or-search
            bind --user -M insert \cn down-or-search
          end

          # Direnv
          direnv hook fish | source

          # Starship Shell
          starship init fish | source
        '';
      };
    };
  };
  users = {
    users = {
      "${settings.username}" = {
        shell = pkgs.fish;
      };
    };
  };
}
