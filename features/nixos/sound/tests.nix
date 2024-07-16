args @ {pkgs, ...}: let
  feature = import ./default.nix args;
in {
  hardware = {
    pulseaudio = {
      enable = {
        test = {
          expr = feature.hardware.pulseaudio.enable;
          expected = false;
        };
      };
    };
  };

  security = {
    rtkit = {
      enable = {
        test = {
          expr = feature.security.rtkit.enable;
          expected = true;
        };
      };
    };
  };

  services = {
    pipewire = {
      enable = {
        test = {
          expr = feature.services.pipewire.enable;
          expected = true;
        };
      };
      alsa = {
        enable = {
          test = {
            expr = feature.services.pipewire.alsa.enable;
            expected = true;
          };
        };
        support32Bit = {
          test = {
            expr = feature.services.pipewire.alsa.support32Bit;
            expected = true;
          };
        };
      };
      pulse = {
        enable = {
          test = {
            expr = feature.services.pipewire.pulse.enable;
            expected = true;
          };
        };
      };
    };
  };

  environment = {
    systemPackages = {
      test_pavucontrol = {
        expr = builtins.elem pkgs.pavucontrol feature.environment.systemPackages;
        expected = true;
      };

      test_pulsemixer = {
        expr = builtins.elem pkgs.pulsemixer feature.environment.systemPackages;
        expected = true;
      };
    };
  };
}
