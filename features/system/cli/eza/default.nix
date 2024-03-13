# eza is a ls replacement.
{
  settings,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    eza
  ];
}
