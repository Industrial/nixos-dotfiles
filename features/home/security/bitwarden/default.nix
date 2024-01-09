{
  settings,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    bitwarden
  ];
}
