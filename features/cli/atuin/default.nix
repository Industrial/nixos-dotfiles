# Atuin is a SQLite-backed shell history with search. It's a replacement for the shell's own history file.
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    atuin
  ];
}
