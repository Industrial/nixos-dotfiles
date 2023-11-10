{pkgs, options, ...}:
{
  imports = [];

  options = {
    hostname = pkgs.lib.mkOption {
      type = pkgs.lib.types.str;
      default = "langhus";
      description = "Hostname for the system";
    };
  };

  config = {
    networking.hostName = options.hostname;
    networking.networkmanager.enable = true;
  };
}
