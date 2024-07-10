args @ {pkgs, ...}: let
  feature = import ./default.nix args;
in {
  environment = {
    systemPackages = {
      test = {
        expr = builtins.elem pkgs.readarr feature.environment.systemPackages;
        expected = true;
      };
    };
  };

  systemd = {
    services = {
      readarr = {
        description = {
          test = {
            expr = feature.systemd.services.readarr.description;
            expected = "Readarr Daemon";
          };
        };

        wantedBy = {
          test = {
            expr = builtins.elem "multi-user.target" feature.systemd.services.readarr.wantedBy;
            expected = true;
          };
        };

        after = {
          test = {
            expr = builtins.elem "network.target" feature.systemd.services.readarr.after;
            expected = true;
          };
        };

        serviceConfig = {
          Type = {
            test = {
              expr = feature.systemd.services.readarr.serviceConfig.Type;
              expected = "simple";
            };
          };

          User = {
            test = {
              expr = feature.systemd.services.readarr.serviceConfig.User;
              expected = "readarr";
            };
          };

          Group = {
            test = {
              expr = feature.systemd.services.readarr.serviceConfig.Group;
              expected = "data";
            };
          };

          ExecStart = {
            test = {
              expr = feature.systemd.services.readarr.serviceConfig.ExecStart;
              expected = "${pkgs.readarr}/bin/Readarr --nobrowser --data=/data/readarr";
            };
          };

          Restart = {
            test = {
              expr = feature.systemd.services.readarr.serviceConfig.Restart;
              expected = "always";
            };
          };

          RestartSec = {
            test = {
              expr = feature.systemd.services.readarr.serviceConfig.RestartSec;
              expected = 5;
            };
          };
        };
      };
    };

    tmpfiles = {
      rules = {
        data-readarr = {
          data = {
            expr = builtins.elem "d /data/readarr 0770 readarr data - -" feature.systemd.tmpfiles.rules;
            expected = true;
          };
        };

        data-readarr-data = {
          data = {
            expr = builtins.elem "d /data/readarr/data 0770 readarr data - -" feature.systemd.tmpfiles.rules;
            expected = true;
          };
        };
      };
    };
  };

  users = {
    users = {
      readarr = {
        isSystemUser = {
          test = {
            expr = feature.users.users.readarr.isSystemUser;
            expected = true;
          };
        };

        home = {
          test = {
            expr = feature.users.users.readarr.home;
            expected = "/home/readarr";
          };
        };

        createHome = {
          test = {
            expr = feature.users.users.readarr.createHome;
            expected = true;
          };
        };

        group = {
          test = {
            expr = feature.users.users.readarr.group;
            expected = "readarr";
          };
        };

        extraGroups = {
          test = {
            expr = feature.users.users.readarr.extraGroups;
            expected = ["data"];
          };
        };
      };
    };

    groups = {
      readarr = {
        test = {
          expr = feature.users.groups.readarr;
          expected = {};
        };
      };
    };
  };
}
