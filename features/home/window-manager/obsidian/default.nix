# Note Taker.
{
  c9config,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    obsidian
  ];

  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.permittedInsecurePackages = [
    "electron-25.9.0"
  ];
}
