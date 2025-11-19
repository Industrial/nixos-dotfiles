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
      interactiveShellInit = ''
        # Disable greeting
        function fish_greeting
        end

        # Enable Fish plugins
        source ${havamalPlugin}/share/fish/vendor_conf.d/Hávamál.fish

        # Add local bin to PATH
        set -x PATH "$PATH:$HOME/.local/bin"

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

  environment = {
    shells = with pkgs; [
      fish
    ];
    sessionVariables = {
      EDITOR = "vnim";
      GIT_EDITOR = "nvim";
      DIFFPROG = "nvim -d";
      XDG_CACHE_HOME = "$HOME/.cache";
      XDG_CONFIG_HOME = "$HOME/.config";
      XDG_DATA_HOME = "$HOME/.local/share";
      XDG_STATE_HOME = "$HOME/.local/state";
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
