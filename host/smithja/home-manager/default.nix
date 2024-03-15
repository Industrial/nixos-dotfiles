{
  settings,
  pkgs,
  inputs,
  ...
}: {
  imports = [
    # Home
    ../../../features/home/home

    # Programming
    ../../../features/home/programming/git
    ../../../features/home/programming/vscode
  ];
}
