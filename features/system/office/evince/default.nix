# evince is a document reader (gnome).
{
  settings,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    evince
  ];
}
