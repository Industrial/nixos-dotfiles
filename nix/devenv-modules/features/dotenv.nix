{
  lib,
  config,
  ...
}: let
  cfg = config.local.features.dotenv;
in {
  options.local.features.dotenv.enable = lib.mkEnableOption "devenv dotenv loading";

  config = lib.mkIf cfg.enable {
    dotenv.enable = true;
  };
}
