# FH is the cli for FlakeHub.
{
  settings,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    fh
  ];
}
