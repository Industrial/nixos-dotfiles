# Communication Profile
# Communication applications
{
  config,
  lib,
  ...
}: {
  options.profiles.communication.enable = lib.mkEnableOption "the communication profile";

  config = lib.mkIf config.profiles.communication.enable {
    features.communication.discord.enable = true;
    # features.communication.fractal.enable = true;
    features.communication.signal-desktop.enable = true;
    # features.communication.teams.enable = true;
    # features.communication.telegram.enable = true;
    # features.communication.weechat.enable = true;
  };
}
