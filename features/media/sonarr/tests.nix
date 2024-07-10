args @ {pkgs, ...}: let
  feature = import ./default.nix args;
in {
  environment = {
    systemPackages = {
      test = {
        expr = builtins.elem pkgs.sonarr feature.environment.systemPackages;
        expected = true;
      };
    };
  };

  systemd = {
    services = {
      sonarr = {
        description = {
          test = {
            expr = feature.systemd.services.sonarr.description;
            expected = "Sonarr Daemon";
          };
        };

        wantedBy = {
          test = {
            expr = builtins.elem "multi-user.target" feature.systemd.services.sonarr.wantedBy;
            expected = true;
          };
        };

        after = {
          test = {
            expr = builtins.elem "network.target" feature.systemd.services.sonarr.after;
            expected = true;
          };
        };

        serviceConfig = {
          Type = {
            test = {
              expr = feature.systemd.services.sonarr.serviceConfig.Type;
              expected = "simple";
            };
          };

          User = {
            test = {
              expr = feature.systemd.services.sonarr.serviceConfig.User;
              expected = "sonarr";
            };
          };

          Group = {
            test = {
              expr = feature.systemd.services.sonarr.serviceConfig.Group;
              expected = "data";
            };
          };

          ExecStart = {
            test = {
              expr = feature.systemd.services.sonarr.serviceConfig.ExecStart;
              expected = "${pkgs.sonarr}/bin/Sonarr --nobrowser --data=/data/sonarr";
            };
          };

          Restart = {
            test = {
              expr = feature.systemd.services.sonarr.serviceConfig.Restart;
              expected = "always";
            };
          };

          RestartSec = {
            test = {
              expr = feature.systemd.services.sonarr.serviceConfig.RestartSec;
              expected = 5;
            };
          };
        };
      };
    };

    tmpfiles = {
      rules = {
        data-sonarr = {
          data = {
            expr = builtins.elem "d /data/sonarr 0770 sonarr data - -" feature.systemd.tmpfiles.rules;
            expected = true;
          };
        };

        data-sonarr-data = {
          data = {
            expr = builtins.elem "d /data/sonarr/data 0770 sonarr data - -" feature.systemd.tmpfiles.rules;
            expected = true;
          };
        };
      };
    };
  };

  users = {
    users = {
      sonarr = {
        isSystemUser = {
          test = {
            expr = feature.users.users.sonarr.isSystemUser;
            expected = true;
          };
        };

        home = {
          test = {
            expr = feature.users.users.sonarr.home;
            expected = "/home/sonarr";
          };
        };

        createHome = {
          test = {
            expr = feature.users.users.sonarr.createHome;
            expected = true;
          };
        };

        group = {
          test = {
            expr = feature.users.users.sonarr.group;
            expected = "sonarr";
          };
        };

        extraGroups = {
          test = {
            expr = feature.users.users.sonarr.extraGroups;
            expected = ["data"];
          };
        };
      };
    };

    groups = {
      sonarr = {
        test = {
          expr = feature.users.groups.sonarr;
          expected = {};
        };
      };
    };
  };
}
