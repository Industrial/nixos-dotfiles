args @ {pkgs, ...}: let
  feature = import ./default.nix args;
in {
  environment = {
    systemPackages = {
      test = {
        expr = builtins.elem pkgs.radarr feature.environment.systemPackages;
        expected = true;
      };
    };
  };

  systemd = {
    services = {
      radarr = {
        description = {
          test = {
            expr = feature.systemd.services.radarr.description;
            expected = "Radarr Daemon";
          };
        };

        wantedBy = {
          test = {
            expr = builtins.elem "multi-user.target" feature.systemd.services.radarr.wantedBy;
            expected = true;
          };
        };

        after = {
          test = {
            expr = builtins.elem "network.target" feature.systemd.services.radarr.after;
            expected = true;
          };
        };

        serviceConfig = {
          Type = {
            test = {
              expr = feature.systemd.services.radarr.serviceConfig.Type;
              expected = "simple";
            };
          };

          User = {
            test = {
              expr = feature.systemd.services.radarr.serviceConfig.User;
              expected = "radarr";
            };
          };

          Group = {
            test = {
              expr = feature.systemd.services.radarr.serviceConfig.Group;
              expected = "data";
            };
          };

          ExecStart = {
            test = {
              expr = feature.systemd.services.radarr.serviceConfig.ExecStart;
              expected = "${pkgs.radarr}/bin/Radarr --nobrowser --data=/data/radarr";
            };
          };

          Restart = {
            test = {
              expr = feature.systemd.services.radarr.serviceConfig.Restart;
              expected = "always";
            };
          };

          RestartSec = {
            test = {
              expr = feature.systemd.services.radarr.serviceConfig.RestartSec;
              expected = 5;
            };
          };
        };
      };
    };

    tmpfiles = {
      rules = {
        data-radarr = {
          data = {
            expr = builtins.elem "d /data/radarr 0770 radarr data - -" feature.systemd.tmpfiles.rules;
            expected = true;
          };
        };

        data-radarr-data = {
          data = {
            expr = builtins.elem "d /data/radarr/data 0770 radarr data - -" feature.systemd.tmpfiles.rules;
            expected = true;
          };
        };
      };
    };
  };

  users = {
    users = {
      radarr = {
        isSystemUser = {
          test = {
            expr = feature.users.users.radarr.isSystemUser;
            expected = true;
          };
        };

        home = {
          test = {
            expr = feature.users.users.radarr.home;
            expected = "/home/radarr";
          };
        };

        createHome = {
          test = {
            expr = feature.users.users.radarr.createHome;
            expected = true;
          };
        };

        group = {
          test = {
            expr = feature.users.users.radarr.group;
            expected = "radarr";
          };
        };

        extraGroups = {
          test = {
            expr = feature.users.users.radarr.extraGroups;
            expected = ["data"];
          };
        };
      };
    };

    groups = {
      radarr = {
        test = {
          expr = feature.users.groups.radarr;
          expected = {};
        };
      };
    };
  };
}
