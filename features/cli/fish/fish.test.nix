{pkgs, ...}: let
  mockPkgs = {
    stdenv = {
      mkDerivation = attrs: {
        name = attrs.name;
        version = attrs.version;
        src = attrs.src;
        installPhase = attrs.installPhase;
      };
    };
    fish = "mock-fish-package";
    havamal = {
      share = "mock-havamal-content";
    };
  };

  mockSettings = {
    username = "testuser";
  };

  fishModule = import ./default.nix {
    pkgs = mockPkgs;
    settings = mockSettings;
  };
in {
  # Test that required packages are available
  testRequiredPackagesAvailable = {
    expr = builtins.hasAttr "fish" mockPkgs;
    expected = true;
  };

  # Test that fish is enabled
  testFishEnabled = {
    expr = fishModule.programs.fish.enable;
    expected = true;
  };

  # Test that fish is in shells
  testFishInShells = {
    expr = builtins.elem mockPkgs.fish fishModule.environment.shells;
    expected = true;
  };

  # Test that fish config is created
  testFishConfig = {
    expr = builtins.hasAttr "fish/config.fish" fishModule.environment.etc;
    expected = true;
  };

  # # Test that fish config content is correct
  # testFishConfigContent = {
  #   expr = fishModule.environment.etc."fish/config.fish".text;
  #   expected = ''
  #     # Disable greeting
  #     function fish_greeting
  #     end
  #     # Enable Fish plugins
  #     source mock-havamal-content
  #     # Variables
  #     # set -x EDITOR "vim"
  #     # set -x GIT_EDITOR "vim"
  #     # set -x DIFFPROG "vim -d"
  #     set -x XDG_CACHE_HOME "$HOME/.cache"
  #     set -x XDG_CONFIG_HOME "$HOME/.config"
  #     set -x XDG_DATA_HOME "$HOME/.local/share"
  #     set -x XDG_STATE_HOME "$HOME/.local/state"
  #     # this is for Cursor IDE
  #     set -x NO_NEW_PRIVILEGES 0
  #     # Use vim keybindings.
  #     fish_vi_key_bindings
  #     # Remove default aliases.
  #     functions -e l
  #     functions -e ll
  #     functions -e ls
  #     # Keybindings
  #     function fish_user_key_bindings
  #       bind --user -M insert \cp up-or-search
  #       bind --user -M insert \cn down-or-search
  #     end
  #     # Direnv
  #     direnv hook fish | source
  #     # Starship Shell
  #     starship init fish | source
  #   '';
  # };

  # Test that user shell is set to fish
  testUserShell = {
    expr = fishModule.users.users.testuser.shell;
    expected = mockPkgs.fish;
  };
}
