# Browser
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    # ungoogled-chromium
    google-chrome
  ];
}
