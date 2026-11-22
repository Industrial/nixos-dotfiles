# vdeploy (rust/tools/vdeploy): the fleet's pull-based deploy agent. It polls main, verifies
# the commit, evaluates and realises this host's system, and diffs it against
# /run/current-system with vdiff.
#
#   mode = "observe" (GH-159, the default): it logs the switch it WOULD make, and never
#     switches. comin stays the deployer.
#   mode = "deploy" (GH-160, the take-over): every plan that switches runs `vdeploy apply` in
#     a transient unit (vdeploy-apply): switch-to-configuration test, vhealth on the new
#     generation's own probes, then `nix-env -p /nix/var/nix/profiles/system --set` and
#     switch-to-configuration boot, or a rollback with `test` to the previous generation.
#     Nothing is written to the boot entries until the health check passes. comin is forced
#     off, and its unit is replaced by a TOMBSTONE (below).
#
# Taking over from comin, live: the generation that turns deploy mode on is applied BY
# comin, which runs switch-to-configuration as its own child, with its output piped into
# itself. If that generation simply dropped comin.service, the switch would stop comin and
# kill itself halfway. So deploy mode keeps a comin.service unit that is a tombstone:
# restartIfChanged = false (the switch neither stops nor restarts it, so comin finishes the
# switch), Restart = "no" and no wantedBy (comin then exits, as it does whenever its unit
# file changes, and stays down; it never starts at boot). vdeploy waits until no
# switch-to-configuration is left in comin's cgroup, then stops the unit itself. Going back
# (the rollback option) is safe by construction: vdeploy's switch runs in vdeploy-apply, not
# in vdeploy.service, and comin starts again from its own wantedBy.
#
# Which hosts deploy: those with the `vdeploy` role in common/fleet.nix (a host fact, so no
# host file names the mode).
#
# Take-over rollback: `features.nix.vdeploy.mode = lib.mkForce "observe";` (or dropping the
# role) brings comin back: the host keeps `features.fleet.comin.enable = true`, which
# deploy mode overrides.
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
# node_exporter: the textfile directory is features/monitoring/textfile-collector.nix's,
# imported here as vverify and vhealth import it, so the directory and the exporter flag
# exist once however many writers a host runs (node_exporter refuses a repeated
# --collector.textfile.directory). The earlier "unless vverify is on" test missed vhealth,
# which also adds the flag (GH-221).
#
# The wake (GH-246, deploy mode): `vdeploy wake` writes a byte into the FIFO /run/vdeploy/wake
# (root:vdeploy-wake 0620; the group is the fleet's operator only) and the poller polls main
# now instead of at the end of its interval. It carries nothing, so the pinned URL, the
# verification, the debounce, the bad marks and the health gate still decide; the interval
# poll stays the default. `fleet deploy` is `ssh <host> vdeploy wake --wait`. Rollback:
# `features.nix.vdeploy.wake.enable = false;`.
#
# Observe-mode rollback: `features.nix.vdeploy.enable = lib.mkForce false;` removes the unit.
#
# Health probe (on the host, no root needed):
#   systemctl is-active vdeploy \
#     && grep -q '^vdeploy_last_poll_timestamp_seconds ' /var/lib/prometheus-node-exporter-text/vdeploy.prom \
#     && journalctl -u vdeploy -o cat | grep -E 'would switch|nothing to switch' | tail -n 3
{
  config,
  lib,
  options,
  pkgs,
  ...
} @ args: let
  cfg = config.features.nix.vdeploy;
  deploy = cfg.mode == "deploy";
  # Which hosts vdeploy deploys is a host fact: the `vdeploy` role in common/fleet.nix.
  fleet = import ../../../common/fleet.nix;
  deploysHere = fleet.hosts ? ${cfg.host} && fleet.hasRole "vdeploy" cfg.host;
  systemd = config.systemd.package;
  gcroots = "/nix/var/nix/gcroots/vdeploy";
  # features.fleet.comin exists on hosts (lib/features.nix declares it); a suite that
  # evaluates this module alone has no such option, and nothing to force off.
  cominOption = lib.hasAttrByPath ["features" "fleet" "comin" "enable"] options;
  cominOn = config.services.comin.enable or false;
  # What `vdeploy apply` is told, by the daemon (from these same flags) and by the
  # vdeploy-apply wrapper.
  applyArgs = [
    "--health-window"
    cfg.healthWindow
    "--systemctl"
    "${systemd}/bin/systemctl"
    "--nix-env"
    "${config.nix.package}/bin/nix-env"
    "--nix-store"
    "${config.nix.package}/bin/nix-store"
    "--profile"
    "/nix/var/nix/profiles/system"
    "--gcroot"
    "${gcroots}/candidate"
    # The probes run as `vhealth` (features/nix/vhealth's static user, allowed to use the
    # Nix daemon), as vhealth's own daemon runs them: a Nix daemon that answers root but
    # not other users is not healthy. Never nobody: hosts restrict allowed-users.
    "--health-as"
    "vhealth"
    "--setpriv"
    "${pkgs.util-linux}/bin/setpriv"
  ];
  # `vdeploy-apply [TOPLEVEL]`: by hand, what the daemon does for each plan (the same
  # transient unit, the same health check and rollback). Without a toplevel it only
  # finishes an interrupted apply.
  applyNow = pkgs.writeShellScriptBin "vdeploy-apply" ''
    set -eu
    extra=()
    if [ $# -gt 0 ]; then
      extra=(--toplevel "$(${pkgs.coreutils}/bin/readlink -f "$1")")
    fi
    exec ${systemd}/bin/systemd-run --unit=vdeploy-apply \
      --description="vdeploy apply: switch, health check, keep or roll back" \
      --service-type=exec --collect --wait --quiet --no-ask-password \
      ${vdeploy}/bin/vdeploy apply \
      --state-dir /var/lib/vdeploy --textfile-dir ${textfileDir} \
      ${lib.escapeShellArgs applyArgs} "''${extra[@]}"
  '';
  vdeploy = pkgs.callPackage ../../../rust/tools/vdeploy/default.nix {};
  textfileDir = "/var/lib/prometheus-node-exporter-text";
  settings = args.settings or {};
  inherit (cfg.dotfiles) user;
  userGroup = let
    g = config.users.users.${user}.group or "";
  in
    if g == ""
    then "users"
    else g;
  userHome = config.users.users.${user}.home or "/home/${user}";
  # The wake FIFO (GH-246), in deploy mode only.
  wakeFifo = "/run/vdeploy/wake";
  wakes = deploy && cfg.wake.enable;
in {
  imports = [../../monitoring/textfile-collector.nix];

  options.features.nix.vdeploy = {
    mode = lib.mkOption {
      type = lib.types.enum ["observe" "deploy"];
      default =
        if deploysHere
        then "deploy"
        else "observe";
      defaultText = lib.literalExpression ''if the host has the "vdeploy" role in common/fleet.nix then "deploy" else "observe"'';
      description = ''
        observe: plan and log the switch, never make it (comin deploys). deploy: switch,
        health-check with vhealth, keep or roll back; comin is retired. Hosts with the
        `vdeploy` role in common/fleet.nix deploy. The take-over's rollback is
        lib.mkForce "observe" (or dropping the role).
      '';
    };
    healthWindow = lib.mkOption {
      type = lib.types.str;
      default = "2m";
      description = ''
        Deploy mode: how long a new generation may take to become healthy (vhealth's settle
        window) before it is rolled back.
      '';
    };
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
      # A host fact: common/fleet.nix's `deployDebounce` (mimir, the slow host), else none.
      default = fleet.hosts.${cfg.host}.deployDebounce or "0";
      defaultText = lib.literalExpression ''(import common/fleet.nix).hosts.''${host}.deployDebounce or "0"'';
      example = "10m";
      description = ''
        How long main must stay on one commit before a plan starts (0: no wait). Give slow
        hosts a longer window. This never cancels a plan in flight.
      '';
    };
    # GH-246: let an operator make vdeploy poll main now (`vdeploy wake`, `fleet deploy`).
    wake = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Deploy mode: the wake FIFO ${wakeFifo}. A write makes the poller poll main now
          instead of at the end of its interval; it carries nothing, so the pinned URL,
          the verification, the debounce, the bad marks and the health gate still decide.
          The poll on `interval` stays the default and the fallback.
        '';
      };
      operators = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        # The operator where it is a normal user on this host (every fleet host); a host
        # without one (a test node) has nobody who may wake it, never a stand-in.
        default = lib.filter (u: config.users.users.${u}.isNormalUser or false) [user];
        defaultText = lib.literalExpression "[ settings.username ] (where it is a normal user)";
        description = ''
          Who may wake vdeploy (group vdeploy-wake): the fleet's operator, the user whose
          keys features/fleet/operator-ssh authorises fleet-wide. Normal users only.
        '';
      };
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

  config = lib.mkMerge [
    {
      environment.systemPackages = [vdeploy];

      systemd.services.vdeploy = {
        description =
          if deploy
          then "vdeploy (deploy mode): switches this host to main, health-checked, with rollback"
          else "vdeploy (observe mode): plans the switch to main, never makes it";
        wantedBy = ["multi-user.target"];
        wants = ["network-online.target"];
        after = ["network-online.target" "nix-daemon.socket" "systemd-tmpfiles-setup.service"];

        # setpriv and env (util-linux, coreutils) run git as the user.
        path = [pkgs.git config.nix.package pkgs.util-linux pkgs.coreutils] ++ lib.optional deploy systemd;
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
            ++ lib.optionals deploy ([
                "--mode"
                "deploy"
                "--systemd-run"
                "${systemd}/bin/systemd-run"
              ]
              ++ applyArgs
              ++ lib.optionals wakes ["--wake-fifo" wakeFifo])
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
          # Readable by users: last.json, deploys.jsonl and plan.json hold no secrets, and
          # are how a user (or an agent, without root) sees what vdeploy did.
          StateDirectoryMode = "0755";
          # node_exporter (its own user) reads what is written: 0644 files.
          UMask = "0022";

          ProtectSystem = "strict";
          ProtectHome = "read-only";
          # `-`: a host without the checkout still starts (it is reported missing).
          ReadWritePaths = [textfileDir] ++ lib.optional cfg.dotfiles.enable "-${cfg.dotfiles.path}" ++ lib.optional wakes "-/run/vdeploy";
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
    }

    (lib.mkIf deploy {
      assertions =
        [
          {
            assertion = config.environment.etc ? "vhealth/probes.json";
            message = "features.nix.vdeploy.mode = \"deploy\" decides keep or rollback with vhealth: enable features.nix.vhealth (and its probes) on this host.";
          }
        ]
        # Only operators may wake vdeploy (GH-246): normal users, never a system user.
        ++ lib.optionals wakes (map (u: {
            assertion = (config.users.users.${u}.isNormalUser or false) && !(config.users.users.${u}.isSystemUser or false);
            message = "features.nix.vdeploy.wake.operators: ${u} must be a normal (operator) user, not a system user.";
          })
          cfg.wake.operators);

      environment.systemPackages = [applyNow];

      # The wake (GH-246): a FIFO the operators may write and nobody else may open. tmpfiles
      # creates it at boot and on every switch, before vdeploy starts reading it.
      users.groups.vdeploy-wake.members = lib.mkIf wakes cfg.wake.operators;

      # The candidate generation's GC root, while an apply decides on it.
      systemd.tmpfiles.rules =
        ["d ${gcroots} 0755 root root - -"]
        ++ lib.optionals wakes [
          "d /run/vdeploy 0755 root root - -"
          "p ${wakeFifo} 0620 root vdeploy-wake - -"
        ];

      # comin's tombstone (see the header). Only where the real comin is off, so the rollback
      # option gets the real unit back.
      systemd.services.comin = lib.mkIf (!cominOn) {
        description = "comin, retired by vdeploy (a tombstone: features/nix/vdeploy)";
        restartIfChanged = false;
        wantedBy = lib.mkForce [];
        serviceConfig = {
          Type = "simple";
          ExecStart = "${pkgs.coreutils}/bin/true";
          Restart = lib.mkForce "no";
        };
      };
    })

    (lib.optionalAttrs cominOption {
      features.fleet.comin.enable = lib.mkIf deploy (lib.mkForce false);
    })
  ];
}
