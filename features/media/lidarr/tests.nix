args @ {pkgs, ...}: let
  feature = import ./default.nix args;
in {
  environment = {
    systemPackages = {
      test = {
        expr = builtins.elem pkgs.lidarr feature.environment.systemPackages;
        expected = true;
      };
    };
  };

  systemd = {
    services = {
      lidarr = {
        description = {
          test = {
            expr = feature.systemd.services.lidarr.description;
            expected = "Lidarr Daemon";
          };
        };

        wantedBy = {
          test = {
            expr = builtins.elem "multi-user.target" feature.systemd.services.lidarr.wantedBy;
            expected = true;
          };
        };

        after = {
          test = {
            expr = builtins.elem "network.target" feature.systemd.services.lidarr.after;
            expected = true;
          };
        };

        serviceConfig = {
          Type = {
            test = {
              expr = feature.systemd.services.lidarr.serviceConfig.Type;
              expected = "simple";
            };
          };

          User = {
            test = {
              expr = feature.systemd.services.lidarr.serviceConfig.User;
              expected = "lidarr";
            };
          };

          Group = {
            test = {
              expr = feature.systemd.services.lidarr.serviceConfig.Group;
              expected = "data";
            };
          };

          ExecStart = {
            test = {
              expr = feature.systemd.services.lidarr.serviceConfig.ExecStart;
              expected = "${pkgs.lidarr}/bin/Lidarr --nobrowser --data=/data/lidarr";
            };
          };

          Restart = {
            test = {
              expr = feature.systemd.services.lidarr.serviceConfig.Restart;
              expected = "always";
            };
          };

          RestartSec = {
            test = {
              expr = feature.systemd.services.lidarr.serviceConfig.RestartSec;
              expected = 5;
            };
          };
        };
      };
    };

    tmpfiles = {
      rules = {
        data-lidarr = {
          data = {
            expr = builtins.elem "d /data/lidarr 0770 lidarr data - -" feature.systemd.tmpfiles.rules;
            expected = true;
          };
        };

        data-lidarr-data = {
          data = {
            expr = builtins.elem "d /data/lidarr/data 0770 lidarr data - -" feature.systemd.tmpfiles.rules;
            expected = true;
          };
        };
      };
    };
  };

  users = {
    users = {
      lidarr = {
        isSystemUser = {
          test = {
            expr = feature.users.users.lidarr.isSystemUser;
            expected = true;
          };
        };

        home = {
          test = {
            expr = feature.users.users.lidarr.home;
            expected = "/home/lidarr";
          };
        };

        createHome = {
          test = {
            expr = feature.users.users.lidarr.createHome;
            expected = true;
          };
        };

        group = {
          test = {
            expr = feature.users.users.lidarr.group;
            expected = "lidarr";
          };
        };

        extraGroups = {
          test = {
            expr = feature.users.users.lidarr.extraGroups;
            expected = ["data"];
          };
        };
      };
    };

    groups = {
      lidarr = {
        test = {
          expr = feature.users.groups.lidarr;
          expected = {};
        };
      };
    };
  };
}
