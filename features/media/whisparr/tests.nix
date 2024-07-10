args @ {pkgs, ...}: let
  feature = import ./default.nix args;
in {
  environment = {
    systemPackages = {
      test = {
        expr = builtins.elem pkgs.whisparr feature.environment.systemPackages;
        expected = true;
      };
    };
  };

  systemd = {
    services = {
      whisparr = {
        description = {
          test = {
            expr = feature.systemd.services.whisparr.description;
            expected = "Whisparr Daemon";
          };
        };

        wantedBy = {
          test = {
            expr = builtins.elem "multi-user.target" feature.systemd.services.whisparr.wantedBy;
            expected = true;
          };
        };

        after = {
          test = {
            expr = builtins.elem "network.target" feature.systemd.services.whisparr.after;
            expected = true;
          };
        };

        serviceConfig = {
          Type = {
            test = {
              expr = feature.systemd.services.whisparr.serviceConfig.Type;
              expected = "simple";
            };
          };

          User = {
            test = {
              expr = feature.systemd.services.whisparr.serviceConfig.User;
              expected = "whisparr";
            };
          };

          Group = {
            test = {
              expr = feature.systemd.services.whisparr.serviceConfig.Group;
              expected = "data";
            };
          };

          ExecStart = {
            test = {
              expr = feature.systemd.services.whisparr.serviceConfig.ExecStart;
              expected = "${pkgs.whisparr}/bin/Whisparr --nobrowser --data=/data/whisparr";
            };
          };

          Restart = {
            test = {
              expr = feature.systemd.services.whisparr.serviceConfig.Restart;
              expected = "always";
            };
          };

          RestartSec = {
            test = {
              expr = feature.systemd.services.whisparr.serviceConfig.RestartSec;
              expected = 5;
            };
          };
        };
      };
    };

    tmpfiles = {
      rules = {
        data-whisparr = {
          data = {
            expr = builtins.elem "d /data/whisparr 0770 whisparr data - -" feature.systemd.tmpfiles.rules;
            expected = true;
          };
        };

        data-whisparr-data = {
          data = {
            expr = builtins.elem "d /data/whisparr/data 0770 whisparr data - -" feature.systemd.tmpfiles.rules;
            expected = true;
          };
        };
      };
    };
  };

  users = {
    users = {
      whisparr = {
        isSystemUser = {
          test = {
            expr = feature.users.users.whisparr.isSystemUser;
            expected = true;
          };
        };

        home = {
          test = {
            expr = feature.users.users.whisparr.home;
            expected = "/home/whisparr";
          };
        };

        createHome = {
          test = {
            expr = feature.users.users.whisparr.createHome;
            expected = true;
          };
        };

        group = {
          test = {
            expr = feature.users.users.whisparr.group;
            expected = "whisparr";
          };
        };

        extraGroups = {
          test = {
            expr = feature.users.users.whisparr.extraGroups;
            expected = ["data"];
          };
        };
      };
    };

    groups = {
      whisparr = {
        test = {
          expr = feature.users.groups.whisparr;
          expected = {};
        };
      };
    };
  };
}
