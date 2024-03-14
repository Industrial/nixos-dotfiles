{
  settings,
  pkgs,
  inputs,
  ...
}: {
  imports = [
    # CLI
    ../../../features/home/cli/fish
    ../../../features/home/cli/zellij

    # Home
    ../../../features/home/home

    # Programming
    ../../../features/home/programming/git
    ../../../features/home/programming/vscode
  ];
}
