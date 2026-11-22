# Colocated suite for features/cli/vlocate: the package, the three shell hooks, and nix-index
# giving way in fish and zsh only.
let
  assay = import ./../../../common/assay/default.nix;
  nixos = import ./../../../common/assay/nixos.nix;
  inherit (nixos) lib;

  # The option vlocate writes to, declared as features/cli/shell-init declares it
  # (programs.nix-index is nixpkgs' own).
  stubs = {
    options.cli.shellInit.extraAutoload = lib.mkOption {
      type = lib.types.attrsOf lib.types.path;
      default = {};
    };
  };
  plain = nixos.eval {modules = [./default.nix stubs];};
  shells = nixos.eval {
    modules = [
      ./default.nix
      stubs
      {
        programs.fish.enable = true;
        programs.zsh.enable = true;
      }
    ];
  };
  pkgNames = c: map (p: p.pname or "") c.environment.systemPackages;
in
  assay.suite "cli-vlocate" {
    installsTheCrate = assay.eq (builtins.elem "vlocate" (pkgNames plain)) true;
    nushellHookThroughShellInit = assay.eq (builtins.attrNames plain.cli.shellInit.extraAutoload) ["60-vlocate.nu"];
    nushellHookSetsTheHook = assay.eq (lib.hasInfix "hooks.command_not_found" (builtins.readFile ./vlocate.nu)) true;
    fishHook = assay.eq (lib.hasInfix "function fish_command_not_found" shells.programs.fish.interactiveShellInit) true;
    zshHook = assay.eq (lib.hasInfix "command_not_found_handler()" shells.programs.zsh.interactiveShellInit) true;
    # No zsh on the host: nothing written for it.
    noZshHookWithoutZsh = assay.eq (lib.hasInfix "command_not_found_handler" plain.programs.zsh.interactiveShellInit) false;
    # One hint per missing command: nix-index's fish and zsh hooks give way; bash keeps its.
    nixIndexGivesWayInFishAndZsh = assay.eq [plain.programs.nix-index.enableFishIntegration plain.programs.nix-index.enableZshIntegration plain.programs.nix-index.enableBashIntegration] [false false true];
  }
