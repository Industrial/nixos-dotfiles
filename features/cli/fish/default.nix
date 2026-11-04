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

        # FZF keybindings (Ctrl-R for history search, Ctrl-T for file search, Alt-C for directory change)
        fzf --fish | source

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

  # `environment.sessionVariables` used to be declared here. It is a global attribute with
  # nothing fish-specific about it, and it now lives in features/cli/shell-init, which is what
  # carries it into the shells NixOS's own POSIX glue does not reach.
  environment = {
    shells = with pkgs; [
      fish
    ];
  };
}
