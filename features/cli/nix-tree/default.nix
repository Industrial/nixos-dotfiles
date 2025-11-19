# nix-tree - Interactively browse dependency graphs of Nix derivations
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    nix-tree
  ];
}
