# Note Taker.
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    obsidian
  ];

  # # TODO: Fix this as soon as Obsidian makes a new release.
  # nixpkgs.config.allowUnfree = true;
  # nixpkgs.config.permittedInsecurePackages =
  #   pkgs.lib.optional (pkgs.obsidian.version == "1.5.3") "electron-25.9.0";
}
