# Note Taker.
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    notion-app
  ];
}
