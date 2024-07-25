# Archive utility.
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    p7zip
  ];
}
