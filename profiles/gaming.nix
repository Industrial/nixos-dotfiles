# Gaming Profile
# Gaming tools and applications
{
  config,
  lib,
  ...
}: {
  options.profiles.gaming.enable = lib.mkEnableOption "the gaming profile";

  config = lib.mkIf config.profiles.gaming.enable {
    features.games.appimage.enable = true;
    features.games.awakened-poe-trade.enable = true;
    features.games.exiled-exchange-2.enable = true;
    features.games.lutris.enable = true;
    features.games.path-of-building.enable = true;
    features.games.wow-classic.enable = true;
    features.games.wowup.enable = true;
  };
}
