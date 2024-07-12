args @ {pkgs, ...}: let
  feature = import ./default.nix args;
in {
  environment = {
    systemPackages = {
      transmission_4 = {
        test = {
          expr = builtins.elem pkgs.transmission_4 feature.environment.systemPackages;
          expected = true;
        };
      };

      transmission_4-qt = {
        test = {
          expr = builtins.elem pkgs.transmission_4-qt feature.environment.systemPackages;
          expected = true;
        };
      };
    };
  };

  services = {
    transmission = {
      enable = {
        test = {
          expr = feature.services.transmission.enable;
          expected = true;
        };
      };

      # TODO: This causes an infinite recursion error.
      # package = {
      #   test = {
      #     expr = feature.services.transmission.package;
      #     expected = pkgs.transmission_4;
      #   };
      # };

      user = {
        test = {
          expr = feature.services.transmission.user;
          expected = "transmission";
        };
      };

      group = {
        test = {
          expr = feature.services.transmission.group;
          expected = pkgs.lib.mkForce "data";
        };
      };

      home = {
        test = {
          expr = feature.services.transmission.home;
          expected = "/home/transmission";
        };
      };

      openFirewall = {
        test = {
          expr = feature.services.transmission.openFirewall;
          expected = false;
        };
      };

      openPeerPorts = {
        test = {
          expr = feature.services.transmission.openPeerPorts;
          expected = false;
        };
      };

      openRPCPort = {
        test = {
          expr = feature.services.transmission.openRPCPort;
          expected = false;
        };
      };

      downloadDirPermissions = {
        test = {
          expr = feature.services.transmission.downloadDirPermissions;
          expected = "770";
        };
      };

      settings = {
        download-dir = {
          test = {
            expr = feature.services.transmission.settings.download-dir;
            expected = "/data/transmission/downloads";
          };
        };

        incomplete-dir = {
          test = {
            expr = feature.services.transmission.settings.incomplete-dir;
            expected = "/data/transmission/incomplete";
          };
        };

        incomplete-dir-enabled = {
          test = {
            expr = feature.services.transmission.settings.incomplete-dir-enabled;
            expected = true;
          };
        };

        watch-dir = {
          test = {
            expr = feature.services.transmission.settings.watch-dir;
            expected = "/data/transmission/watch";
          };
        };

        watch-dir-enabled = {
          test = {
            expr = feature.services.transmission.settings.watch-dir-enabled;
            expected = true;
          };
        };
      };
    };
  };

  users = {
    users = {
      transmission = {
        isSystemUser = {
          test = {
            expr = feature.users.users.transmission.isSystemUser;
            expected = true;
          };
        };

        home = {
          test = {
            expr = feature.users.users.transmission.home;
            expected = "/home/transmission";
          };
        };

        createHome = {
          test = {
            expr = feature.users.users.transmission.createHome;
            expected = true;
          };
        };

        group = {
          test = {
            expr = feature.users.users.transmission.group;
            expected = pkgs.lib.mkForce "transmission";
          };
        };

        extraGroups = {
          test = {
            expr = feature.users.users.transmission.extraGroups;
            expected = ["data"];
          };
        };
      };
    };

    groups = {
      transmission = {
        test = {
          expr = feature.users.groups.transmission;
          expected = {};
        };
      };
    };
  };
}
