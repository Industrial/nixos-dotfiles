# Tealdeer renders tldr pages: community cheatsheets for shell commands. Its binary is tldr.
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    tealdeer
  ];
}
