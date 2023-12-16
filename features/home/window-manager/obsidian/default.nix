# Note Taker.
{
  c9config,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    obsidian
  ];

  # TODO: Fix this as soon as Obsidian makes a new release.
  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.permittedInsecurePackages =
    pkgs.lib.optional (pkgs.obsidian.version == "1.4.16") "electron-25.9.0";
}
