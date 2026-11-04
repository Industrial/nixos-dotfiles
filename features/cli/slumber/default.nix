# Slumber is a terminal HTTP client. It's a TUI replacement for Postman.
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    slumber
  ];
}
