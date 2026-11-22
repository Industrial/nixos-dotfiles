# Colocated suite for features/cli/vswitch: the wrapper it installs calls the
# rust/tools/vswitch crate with this host's absolute tool paths.
let
  assay = import ./../../../common/assay/default.nix;
  nixos = import ./../../../common/assay/nixos.nix;
  inherit (nixos) lib;

  # The real module, evaluated alone (no vmon feature, no vhealth user).
  cfg = nixos.eval {modules = [./default.nix];};
  wrappers = builtins.filter (p: (p.name or "") == "vswitch") cfg.environment.systemPackages;
  # The script text, read from the derivation (no build: nothing is realised here).
  script = (builtins.head wrappers).text;

  # With vhealth's user and vmon on, as on a cli-core host with vhealth.
  full = nixos.eval {
    modules = [
      ./default.nix
      {
        options.features.cli.vmon.enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
        };
        config.users.users.vhealth = {
          isSystemUser = true;
          group = "vhealth";
        };
        config.users.groups.vhealth = {};
      }
    ];
  };
  fullScript = (builtins.head (builtins.filter (p: (p.name or "") == "vswitch") full.environment.systemPackages)).text;
  has = s: f: lib.hasInfix f s;
in
  assay.suite "cli-vswitch" {
    installsOneWrapper = assay.eq (builtins.length wrappers) 1;
    execsTheCrate = assay.eq (has script "-vswitch-0.1.0/bin/vswitch") true;

    # sudo resets PATH, and the transient unit has systemd's: every tool is absolute.
    absoluteTools =
      assay.eq (map (has script) ["--systemd-run /nix/store/" "--nix-env /nix/store/" "--setpriv /nix/store/" "--elevate /run/wrappers/bin/sudo"]) [true true true true];
    passesItsArgs = assay.eq (has script ''"$@"'') true;

    # Alone: no vmon, and no probes user (a host without vhealth has no probes).
    plainWithoutVmonOrVhealth = assay.eq (map (has script) ["--vmon" "--health-as"]) [false false];
    # With them: the build goes through vmon, and probes run as vhealth (never nobody).
    vmonAndVhealthWhenOn = assay.eq (map (has fullScript) ["--vmon /nix/store/" "--health-as vhealth"]) [true true];
  }
