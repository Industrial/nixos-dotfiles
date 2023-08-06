# base16-schemes installs many colorschemes for the terminal.
{pkgs, ...}: {
  home.packages = with pkgs; [
    base16-schemes
  ];
}
