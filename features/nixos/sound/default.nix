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

      # Bluetooth audio tuning (fixes "Missing completion reports" with Sony XM5)
      wireplumber.extraConfig = {
        "50-bluez" = {
          "monitor.bluez.properties" = {
            # Enable high-quality SBC codec (stable fallback from LDAC)
            "bluez5.enable-sbc-xq" = true;
            # Enable mSBC for HFP (better mic quality)
            "bluez5.enable-msbc" = true;
            # Disable HW volume - fixes issues with Sony XM series
            "bluez5.enable-hw-volume" = false;
            # Keep LDAC available but system will fall back if unstable
            "bluez5.codecs" = ["ldac" "aac" "sbc_xq" "sbc"];
          };
        };
      };

      extraConfig.pipewire = {
        "92-bluetooth-buffer" = {
          "context.properties" = {
            # Larger buffer reduces dropouts with Bluetooth
            "default.clock.rate" = 48000;
            "default.clock.quantum" = 1024;
            "default.clock.min-quantum" = 512;
            "default.clock.max-quantum" = 2048;
          };
        };
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
