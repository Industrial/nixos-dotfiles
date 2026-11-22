# vlocate (rust/tools/vlocate, GH-245): where a command comes from, and the
# command-not-found hint for nushell, fish and zsh. Binary: vlocate.
#
#   vlocate hello              which store path of the fleet's systems ships bin/hello,
#                              and which nixpkgs attributes do
#   vlocate hint hello         the shells' hint (nushell)
#   vlocate not-found hello    the hint on stderr, exit 127 (fish, zsh)
#
# It COMPLEMENTS features/cli/nix-index, which answers from the community's prebuilt
# nixpkgs-wide database and stays as it is (nix-locate, comma, bash's hook). vlocate adds:
#   * the fleet's own systems, from the store database: this host's /run/current-system,
#     and on the cache host every fleet host's latest main build (vci's roots);
#   * nixpkgs through nix-locate's prebuilt database, when nix-locate is installed;
#   * a command-not-found hook in nushell (the login shell: nix-index has none), fish and
#     zsh (zsh only where programs.zsh is on). nix-index's own fish and zsh hooks are
#     turned off here, so a missing command gets one hint, not two. bash keeps nix-index's.
#
# Rollback: `features.cli.vlocate.enable = lib.mkForce false;` removes the hooks and gives
# fish and zsh nix-index's back.
{
  config,
  lib,
  pkgs,
  ...
}: let
  vlocate = pkgs.callPackage ../../../rust/tools/vlocate/default.nix {};
in {
  environment.systemPackages = [vlocate];

  # nushell: through the generated vendor autoload (features/cli/shell-init).
  cli.shellInit.extraAutoload."60-vlocate.nu" = ./vlocate.nu;

  # fish: the command-not-found function fish calls.
  programs.fish.interactiveShellInit = lib.mkIf config.programs.fish.enable ''
    function fish_command_not_found
        ${vlocate}/bin/vlocate not-found $argv[1]
    end
  '';

  # zsh, where it is on.
  programs.zsh.interactiveShellInit = lib.mkIf config.programs.zsh.enable ''
    command_not_found_handler() {
      ${vlocate}/bin/vlocate not-found "$1"
      return 127
    }
  '';

  # One hint per missing command: nix-index's fish and zsh hooks give way to these.
  programs.nix-index.enableFishIntegration = lib.mkForce false;
  programs.nix-index.enableZshIntegration = lib.mkForce false;
}
