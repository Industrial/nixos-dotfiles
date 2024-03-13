# e2fsprogs contains hard disk tools. https://en.wikipedia.org/wiki/E2fsprogs
{
  settings,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    e2fsprogs
  ];
}
