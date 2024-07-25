# FH is the cli for FlakeHub.
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    fh
  ];
}
