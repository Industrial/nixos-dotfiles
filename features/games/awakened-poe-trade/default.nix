# Awakened PoE Trade — price-check overlay for Path of Exile 1.
# https://github.com/SnosMe/awakened-poe-trade
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    awakened-poe-trade
  ];
}
