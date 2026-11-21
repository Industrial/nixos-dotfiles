# vdeploy (rust/tools/vdeploy), OBSERVE mode (GH-159): next to comin, this agent polls main,
# verifies the commit, evaluates and realises this host's system, diffs it against
# /run/current-system with vdiff, and logs the switch it WOULD make. It never switches. The
# take-over (switch, vhealth check, rollback) is #160, and comin stays the deployer until
# then.
#
# No starvation (what comin gets wrong): a plan in flight is never cancelled because main
# moved. When it finishes, the next plan is for the newest commit (latest-wins). `debounce`
# can make a host wait for main to go quiet first.
#
# ~/.dotfiles: every poll fast-forwards the user's checkout to main, as the user, and
# refuses when it is dirty, on another branch, ahead or diverged
# (vdeploy_dotfiles_state{state=...}).
#
# Runs as root. Observe mode needs root only to fast-forward another user's checkout
# (setpriv), but the take-over will need it to switch, and both run in this unit. The unit
# is sandboxed: the file system is read-only except its state directory, the textfile
# directory and the checkout. Nix runs through the daemon (NIX_REMOTE=daemon), so the
# daemon does the builds and the store stays read-only here.
#
# node_exporter: the textfile directory is the one features/nix/vverify sets up. Where
# vverify is off, this feature sets it up the same way. The exporter flag is added only
# once, because node_exporter refuses a repeated --collector.textfile.directory.
#
# Rollback: `features.nix.vdeploy.enable = lib.mkForce false;` removes the unit. comin is
# untouched either way.
#
# Health probe (on the host, no root needed):
#   systemctl is-active vdeploy \
#     && grep -q '^vdeploy_last_poll_timestamp_seconds ' /var/lib/prometheus-node-exporter-text/vdeploy.prom \
#     && journalctl -u vdeploy -o cat | grep -E 'would switch|nothing to switch' | tail -n 3
{
  config,
  lib,
  pkgs,
  ...
} @ args: let
  cfg = config.features.nix.vdeploy;
  vdeploy = pkgs.callPackage ../../../rust/tools/vdeploy/default.nix {};
  textfileDir = "/var/lib/prometheus-node-exporter-text";
  group = "prometheus-textfile";
  settings = args.settings or {};
  # vverify (on drakkar already) declares the textfile directory and the exporter flag.
  vverifyOn = lib.attrByPath ["features" "nix" "vverify" "enable"] false config;
  inherit (cfg.dotfiles) user;
  userGroup = let
    g = config.users.users.${user}.group or "";
  in
    if g == ""
    then "users"
    else g;
  userHome = config.users.users.${user}.home or "/home/${user}";
in {
  options.features.nix.vdeploy = {
    host = lib.mkOption {
      type = lib.types.str;
      default = settings.hostname or config.networking.hostName;
      description = "The nixosConfigurations name this host evaluates.";
    };
    url = lib.mkOption {
      type = lib.types.str;
      default = "https://github.com/Industrial/nixos-dotfiles.git";
      description = "Where main is fetched from.";
    };
    branch = lib.mkOption {
      type = lib.types.str;
      default = "main";
      description = "The branch to follow.";
    };
    interval = lib.mkOption {
      type = lib.types.str;
      default = "1m";
      description = "How often main is polled (seconds, or a number with s/m/h/d).";
    };
    debounce = lib.mkOption {
      type = lib.types.str;
      default = "0";
      example = "10m";
      description = ''
        How long main must stay on one commit before a plan starts (0: no wait). Give slow
        hosts a longer window. This never cancels a plan in flight.
      '';
    };
    dotfiles = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Fast-forward the user's dotfiles checkout to main on every poll.";
      };
      user = lib.mkOption {
        type = lib.types.str;
        default = settings.username or "tom";
        description = "Whose checkout, and whom git runs as.";
      };
      path = lib.mkOption {
        type = lib.types.str;
        default = "${userHome}/.dotfiles";
        description = "The checkout.";
      };
    };
  };

  config = {
    environment.systemPackages = [vdeploy];

    users.groups.${group} = {};
    systemd.tmpfiles.rules = lib.mkIf (!vverifyOn) ["d ${textfileDir} 2775 root ${group} - -"];
    services.prometheus.exporters.node.extraFlags =
      lib.mkIf (config.services.prometheus.exporters.node.enable && !vverifyOn)
      ["--collector.textfile.directory=${textfileDir}"];

    systemd.services.vdeploy = {
      description = "vdeploy (observe mode): plans the switch to main, never makes it";
      wantedBy = ["multi-user.target"];
      wants = ["network-online.target"];
      after = ["network-online.target" "nix-daemon.socket" "systemd-tmpfiles-setup.service"];

      # setpriv and env (util-linux, coreutils) run git as the user.
      path = [pkgs.git config.nix.package pkgs.util-linux pkgs.coreutils];
      environment = {
        HOME = "/var/lib/vdeploy";
        XDG_CACHE_HOME = "/var/lib/vdeploy/.cache";
        NIX_REMOTE = "daemon";
      };

      serviceConfig = {
        Type = "simple";
        ExecStart = lib.escapeShellArgs ([
            "${vdeploy}/bin/vdeploy"
            "--host"
            cfg.host
            "--url"
            cfg.url
            "--branch"
            cfg.branch
            "--interval"
            cfg.interval
            "--debounce"
            cfg.debounce
            "--repo"
            "/var/lib/vdeploy/repo"
            "--state-dir"
            "/var/lib/vdeploy"
            "--textfile-dir"
            textfileDir
            "--db"
            "/nix/var/nix/db/db.sqlite"
            "--git"
            "${pkgs.git}/bin/git"
            "--nix"
            "${config.nix.package}/bin/nix"
          ]
          ++ lib.optionals cfg.dotfiles.enable [
            "--dotfiles"
            cfg.dotfiles.path
            "--dotfiles-user"
            user
            "--dotfiles-group"
            userGroup
            "--dotfiles-home"
            userHome
          ]);
        # id_effect_cli interrupts the fibers on SIGINT, running finalizers, and exits 130:
        # a stop, not a failure.
        KillSignal = "SIGINT";
        SuccessExitStatus = [130];
        Restart = "on-failure";
        RestartSec = "1min";

        # Evaluation is this process's own CPU; builds are the daemon's.
        Nice = 10;
        IOSchedulingClass = "best-effort";
        IOSchedulingPriority = 7;

        StateDirectory = "vdeploy";
        StateDirectoryMode = "0750";
        # node_exporter (its own user) reads what is written: 0644 files.
        UMask = "0022";

        ProtectSystem = "strict";
        ProtectHome = "read-only";
        # `-`: a host without the checkout still starts (it is reported missing).
        ReadWritePaths = [textfileDir] ++ lib.optional cfg.dotfiles.enable "-${cfg.dotfiles.path}";
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectKernelLogs = true;
        ProtectControlGroups = true;
        ProtectClock = true;
        ProtectHostname = true;
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        LockPersonality = true;
        NoNewPrivileges = true;
        RestrictAddressFamilies = ["AF_UNIX" "AF_INET" "AF_INET6"];
        SystemCallArchitectures = "native";
        # Root, but only what observe mode uses: reading into the user's home, and
        # setpriv's drop to the user (it loses these on the way).
        CapabilityBoundingSet = ["CAP_SETUID" "CAP_SETGID" "CAP_DAC_READ_SEARCH"];
      };
    };
  };
}
