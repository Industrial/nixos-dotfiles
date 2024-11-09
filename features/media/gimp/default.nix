# Gimp is an open source raster graphics editor.
{pkgs, ...}: {
  environment = {
    systemPackages = with pkgs; [
      gimp
    ];
  };
}
