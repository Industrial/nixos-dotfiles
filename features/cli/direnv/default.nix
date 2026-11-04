# Direnv sources nix environments in project directories as you cd into them.
#
# One of the few CLI features that uses `programs.*` instead of a bare package:
# the payload here is nix-direnv's persistent use_nix/use_flake cache, which
# lands in /etc/direnv/direnvrc — configuration the package alone cannot carry.
# Without it every cd into a devenv/flake project re-evaluates from scratch.
#
# The nixpkgs module installs pkgs.direnv into environment.systemPackages
# itself, so this feature deliberately declares no package list. It also wires
# the bash/zsh/fish/nushell hooks (every enable*Integration defaults to true)
# and sets DIRENV_CONFIG=/etc/direnv.
{...}: {
  programs.direnv = {
    enable = true;
    # Already the module default; stated because it is the reason this feature
    # exists in options form at all, and a silent upstream flip would gut it.
    nix-direnv.enable = true;
  };
}
