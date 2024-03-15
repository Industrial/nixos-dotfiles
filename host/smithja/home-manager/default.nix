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
    ../../../features/home/programming/vscode
  ];
}
