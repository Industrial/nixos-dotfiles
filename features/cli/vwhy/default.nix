# vwhy explains why one store path depends on another (`nix why-depends`'s
# chain, from the store database) and ranks a closure's members by the size
# only they bring in (rust/tools/vwhy). It replaces nix-tree in cli-core
# (GH-182); `vwhy --tui <path>` is the interactive browser, over fzf.
# Binary: vwhy. `vwhy /run/current-system glibc`, `vwhy --top /run/current-system`.
{pkgs, ...}: {
  environment.systemPackages = [
    (pkgs.callPackage ../../../rust/tools/vwhy/default.nix {})
  ];
}
