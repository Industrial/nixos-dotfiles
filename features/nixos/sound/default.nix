{
  lib,
  pkgs,
  ...
}: {
  security = {
    rtkit = {
      enable = true;
    };
  };

  services = {
    pulseaudio = {
      enable = lib.mkForce false;
    };

    pipewire = {
      enable = true;
      alsa = {
        enable = true;
        support32Bit = true;
      };

      pulse = {
        enable = true;
      };
    };
  };

  environment = {
    systemPackages = with pkgs; [
      pavucontrol
      pulsemixer
    ];
  };
}
