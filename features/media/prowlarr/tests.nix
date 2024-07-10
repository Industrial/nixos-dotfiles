args @ {pkgs, ...}: let
  feature = import ./default.nix args;
in {
  environment = {
    systemPackages = {
      test = {
        expr = builtins.elem pkgs.prowlarr feature.environment.systemPackages;
        expected = true;
      };
    };
  };

  systemd = {
    services = {
      prowlarr = {
        description = {
          test = {
            expr = feature.systemd.services.prowlarr.description;
            expected = "Prowlarr Daemon";
          };
        };

        wantedBy = {
          test = {
            expr = builtins.elem "multi-user.target" feature.systemd.services.prowlarr.wantedBy;
            expected = true;
          };
        };

        after = {
          test = {
            expr = builtins.elem "network.target" feature.systemd.services.prowlarr.after;
            expected = true;
          };
        };

        serviceConfig = {
          Type = {
            test = {
              expr = feature.systemd.services.prowlarr.serviceConfig.Type;
              expected = "simple";
            };
          };

          User = {
            test = {
              expr = feature.systemd.services.prowlarr.serviceConfig.User;
              expected = "prowlarr";
            };
          };

          Group = {
            test = {
              expr = feature.systemd.services.prowlarr.serviceConfig.Group;
              expected = "data";
            };
          };

          ExecStart = {
            test = {
              expr = feature.systemd.services.prowlarr.serviceConfig.ExecStart;
              expected = "${pkgs.prowlarr}/bin/Prowlarr --nobrowser --data=/data/prowlarr";
            };
          };

          Restart = {
            test = {
              expr = feature.systemd.services.prowlarr.serviceConfig.Restart;
              expected = "always";
            };
          };

          RestartSec = {
            test = {
              expr = feature.systemd.services.prowlarr.serviceConfig.RestartSec;
              expected = 5;
            };
          };
        };
      };
    };

    tmpfiles = {
      rules = {
        data-prowlarr = {
          data = {
            expr = builtins.elem "d /data/prowlarr 0770 prowlarr data - -" feature.systemd.tmpfiles.rules;
            expected = true;
          };
        };

        data-prowlarr-data = {
          data = {
            expr = builtins.elem "d /data/prowlarr/data 0770 prowlarr data - -" feature.systemd.tmpfiles.rules;
            expected = true;
          };
        };
      };
    };
  };

  users = {
    users = {
      prowlarr = {
        isSystemUser = {
          test = {
            expr = feature.users.users.prowlarr.isSystemUser;
            expected = true;
          };
        };

        home = {
          test = {
            expr = feature.users.users.prowlarr.home;
            expected = "/home/prowlarr";
          };
        };

        createHome = {
          test = {
            expr = feature.users.users.prowlarr.createHome;
            expected = true;
          };
        };

        group = {
          test = {
            expr = feature.users.users.prowlarr.group;
            expected = "prowlarr";
          };
        };

        extraGroups = {
          test = {
            expr = feature.users.users.prowlarr.extraGroups;
            expected = ["data"];
          };
        };
      };
    };

    groups = {
      prowlarr = {
        test = {
          expr = feature.users.groups.prowlarr;
          expected = {};
        };
      };
    };
  };
}
