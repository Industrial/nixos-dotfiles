# vci (rust/tools/vci, GH-242): the fleet's CI on the cache host. Every `interval` it lists
# main and the open same-repository PRs (`git ls-remote`, and GitHub's open-PR list read
# without a token), and builds the next unbuilt head commit for every fleet host (its own
# host first, `ownHost`, GH-287; then common/fleet.nix order):
# `nix eval` of the host's toplevel drvPath, then `nix build` into an out-link under
# /var/lib/vci/roots (an indirect GC root per ref and host, dropped when the PR closes).
#
# Why on the cache host: its /nix/store is what vcache serves (signed on the fly), so a
# commit vci built is in the cache with nothing pushed, and deploying it (vdeploy, vswitch)
# only substitutes. Which host is a host fact: common/fleet.nix `isCacheIn` (drakkar).
#
# What it records: one line per (commit, host) in /var/lib/vci/builds.jsonl (result, drv,
# out, eval and build seconds, vdiff's summary of a PR against main), and vci.prom in
# node_exporter's textfile directory (vci_eval_seconds, vci_build_seconds,
# vci_last_result, vci_pending_commits, ...). The eval seconds are the measurement veval
# (#243) starts from. For each built host, also a veval record in /var/lib/vci/veval (GH-243),
# which vcache on this host serves signed: vdeploy and vswitch use it instead of evaluating.
#
# GitHub commit statuses are OFF by default, and the CI result on PRs stays GitHub
# Actions'. `statusTokenFile` (a root-only file, handed to the unit with LoadCredential,
# so the vci user reads it only from its credentials directory) turns them on: context
# `vci/<host>`, pending then success/failure. The file is read at every post, so whatever
# mints the token can replace it.
#
# `statusApp.privateKeyFile` (GH-247, null by default) is the minted path: a second
# unit, vci-token (rust/tools/vci's second binary), reads the vbump GitHub App's private
# key from that root-only file through LoadCredential, mints an installation token
# narrowed to this repository and "statuses: write" every `statusApp.every` (an
# id_effect Schedule; tokens last an hour), and writes it to /run/vci-token/token
# (vci-token:vci, 0440), which vci reads. vci never sees the key. No secret is
# provisioned here: the user places the key (docs/runbooks/updates.md §7). The statuses
# are not required checks.
#
# Runs as its own static user `vci`: allowed to use the Nix daemon (never trusted-users),
# niced to idle CPU and I/O, memory-capped for the evaluations (`memoryMax`), file system
# read-only except its state and the textfile directory. Builds run in the daemon's
# sandbox as nixbld users, as any user's builds do.
#
# The host is a workstation. vci's own cgroup holds only the evaluations, one at a time
# (one host after another, one commit per step). The builds run in the daemon's cgroup, at
# the daemon's priority, max-jobs and cores, and an untrusted client cannot lower those.
# So vci has at most one build request in flight, and a step does not start (nothing is
# listed, evaluated or built) while vdeploy-apply is active, the 1-minute load is above
# `maxLoad` (default: the number of CPUs), or MemAvailable is below `minFreeMemory` (10G).
#
# Rollback: `features.nix.vci.enable = lib.mkForce false;` stops it; its roots go with
# /var/lib/vci's out-links (remove the directory to let vgc collect them).
#
# Health probe (on the host, no root needed):
#   systemctl is-active vci \
#     && grep '^vci_last_step_timestamp_seconds ' /var/lib/prometheus-node-exporter-text/vci.prom \
#     && tail -n 4 /var/lib/vci/builds.jsonl
{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkOption types;
  cfg = config.features.nix.vci;
  fleet = import ../../../common/fleet.nix;
  vci = pkgs.callPackage ../../../rust/tools/vci/default.nix {};
  textfileDir = "/var/lib/prometheus-node-exporter-text";
  # The accounts are Voltaic's (#457, rust/tools/nixos-users); vci's state is its home.
  voltaic = import ../../nixos/users/voltaic.nix;
  state = voltaic.fragments.vci.users.vci.home;
  restricted = lib.attrByPath ["features" "nixos" "users" "enable"] false config || cfg.restrictedNixUsers;
  minted = cfg.statusApp.privateKeyFile != null;
  tokenDir = "/run/vci-token";
  mintedToken = "${tokenDir}/token";
  minter = [
    "${vci}/bin/vci-token"
    "--app-id"
    cfg.statusApp.appId
    "--key-file"
    "%d/app-key"
    "--out"
    mintedToken
    "--repo-slug"
    cfg.repoSlug
    "--every"
    cfg.statusApp.every
    "--curl"
    "${pkgs.curl}/bin/curl"
    "--openssl"
    (lib.getExe' pkgs.openssl "openssl")
  ];
  args =
    ["${vci}/bin/vci"]
    ++ lib.concatMap (h: ["--host" h]) cfg.hosts
    ++ lib.optionals (cfg.ownHost != null) ["--own-host" cfg.ownHost]
    ++ [
      "--url"
      cfg.url
      "--branch"
      cfg.branch
      "--repo-slug"
      cfg.repoSlug
      "--repo"
      "${state}/repo"
      "--state-dir"
      state
      "--textfile-dir"
      textfileDir
      "--interval"
      cfg.interval
      "--git"
      "${pkgs.git}/bin/git"
      "--curl"
      "${pkgs.curl}/bin/curl"
      "--nix"
      "${config.nix.package}/bin/nix"
      "--systemctl"
      "${config.systemd.package}/bin/systemctl"
      "--min-free-memory"
      cfg.minFreeMemory
    ]
    ++ lib.optionals (cfg.maxLoad != null) ["--max-load" (toString cfg.maxLoad)]
    ++ lib.optional (!cfg.pulls) "--no-pulls"
    ++ lib.optionals (cfg.pullsUrl != null) ["--pulls-url" cfg.pullsUrl]
    ++ lib.optionals (cfg.statusTokenFile != null) ["--status-token-file" "%d/status-token"]
    ++ lib.optionals minted ["--status-token-file" mintedToken];
in {
  imports = [../../monitoring/textfile-collector.nix];

  options.features.nix.vci = {
    hosts = mkOption {
      type = types.listOf types.str;
      default = fleet.order;
      defaultText = lib.literalExpression "(import common/fleet.nix).order";
      description = "The nixosConfigurations to build for every commit: the fleet's hosts.";
    };
    ownHost = mkOption {
      type = types.nullOr types.str;
      default = config.networking.hostName;
      defaultText = lib.literalExpression "config.networking.hostName";
      description = ''
        The host vci runs on (GH-287): when it is one of `hosts`, it is evaluated and built
        first, then the rest in `hosts` order. The cache host's vdeploy plans a new commit at
        once, so its veval record has to be the first one written; the other hosts' vdeploys
        wait out a debounce. The same name profiles/base.nix enables vci by
        (`fleet.isCacheIn`). null: `hosts` order only.
      '';
    };
    url = mkOption {
      type = types.str;
      default = "https://github.com/Industrial/nixos-dotfiles.git";
      description = "Where main and the PR heads are fetched from.";
    };
    branch = mkOption {
      type = types.str;
      default = "main";
      description = "The branch deploys follow; built first.";
    };
    repoSlug = mkOption {
      type = types.str;
      default = "Industrial/nixos-dotfiles";
      description = "OWNER/REPO on GitHub: whose open PRs are built (same-repository PRs only, never forks), and where statuses go.";
    };
    pulls = mkOption {
      type = types.bool;
      default = true;
      description = "Build open PRs as well as main.";
    };
    pullsUrl = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "The open-PR list to read instead of GitHub's (tests: a file:// URL).";
    };
    interval = mkOption {
      type = types.strMatching "[0-9]+[smhd]?";
      default = "2m";
      description = "How often the refs are listed. Unauthenticated, GitHub allows 60 API requests an hour; one is made per step.";
    };
    memoryMax = mkOption {
      type = types.str;
      default = "12G";
      description = "The unit's memory cap: the evaluations run in it (builds run in the daemon's).";
    };
    maxLoad = mkOption {
      type = types.nullOr types.ints.positive;
      default = null;
      description = ''
        Skip a step while the 1-minute load is above this (null: the number of CPUs). The
        builds vci asks for run in the Nix daemon at the daemon's priority, which a client
        that is not trusted cannot lower; vci waits for a quiet host instead.
      '';
    };
    minFreeMemory = mkOption {
      type = types.strMatching "[0-9]+[KMGT]?";
      default = "10G";
      description = "Skip a step while MemAvailable is below this (an evaluation of the largest host peaks near 7.2 GiB).";
    };
    statusTokenFile = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "/var/lib/secrets/vci-status-token";
      description = ''
        Off (null) by default. A root-only file holding a GitHub token allowed to write commit
        statuses on repoSlug (the vbump GitHub App's installation token, #228). It is handed
        to the unit with LoadCredential, read at every post, and never put in argv or the
        environment. Set, vci posts `vci/<host>` statuses on every commit it builds.
      '';
    };
    statusApp = {
      privateKeyFile = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "/var/lib/secrets/vbump-app.pem";
        description = ''
          Off (null) by default (GH-247). A root-only file holding a private key of the
          GitHub App `appId` (a second key of the vbump app). Set, the vci-token unit gets it
          through LoadCredential, mints an installation token for repoSlug with only
          "statuses: write" every `every`, and vci posts `vci/<host>` statuses with it. The
          statuses are informational, not required checks. Exclusive with statusTokenFile.
        '';
      };
      appId = mkOption {
        type = types.strMatching "[0-9]+|Iv[0-9A-Za-z.]+";
        default = "5886494";
        description = "The GitHub App's numeric App ID (or its Client ID): vbump-nixos-dotfiles.";
      };
      every = mkOption {
        type = types.strMatching "[0-9]+[smhd]?";
        default = "30m";
        description = "How often a new token is minted (GitHub's installation tokens last an hour).";
      };
    };
    restrictedNixUsers = mkOption {
      type = types.bool;
      default = false;
      description = "Set where nix.settings.allowed-users is restricted by something other than features/nixos/users (a test); then `vci` is added to it.";
    };
  };

  config = {
    assertions = [
      {
        assertion = !(minted && cfg.statusTokenFile != null);
        message = "features.nix.vci: set statusTokenFile or statusApp.privateKeyFile, not both.";
      }
    ];

    environment.systemPackages = [vci];

    # The accounts are Voltaic's (#457): vci's own, and the minter's (GH-247) when minted.
    # The minter's primary group is vci, so the token it writes
    # (0440) is readable by vci and nobody else, and vci never reads the key.
    users = lib.mkMerge [
      voltaic.fragments.vci
      (lib.mkIf minted voltaic.fragments.vci-token)
    ];

    systemd.services.vci-token = lib.mkIf minted {
      description = "vci-token: the vbump GitHub App's installation token for vci's commit statuses";
      wantedBy = ["multi-user.target"];
      wants = ["network-online.target"];
      after = ["network-online.target"];
      serviceConfig = {
        Type = "simple";
        ExecStart = lib.escapeShellArgs minter;
        Restart = "always";
        RestartSec = "30s";
        User = "vci-token";
        Group = "vci";
        # The key: root-only on disk, copied by systemd into this unit's credentials
        # directory, readable by this unit's user alone.
        LoadCredential = ["app-key:${cfg.statusApp.privateKeyFile}"];
        RuntimeDirectory = "vci-token";
        RuntimeDirectoryMode = "0750";
        # A restart keeps the last token, so vci's posts keep working across it.
        RuntimeDirectoryPreserve = "yes";
        # The token file: 0440, vci-token:vci.
        UMask = "0227";
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectProc = "invisible";
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        NoNewPrivileges = true;
        RestrictSUIDSGID = true;
        LockPersonality = true;
        CapabilityBoundingSet = "";
      };
    };

    # It may use the Nix daemon (never trusted-users), merged into the host's list.
    nix.settings.allowed-users = lib.mkIf restricted ["vci"];

    systemd.services.vci = {
      description = "vci: every fleet host built for main and open PRs, into the cache's store";
      wantedBy = ["multi-user.target"];
      wants = ["network-online.target"] ++ lib.optional minted "vci-token.service";
      after = ["network-online.target" "nix-daemon.socket" "systemd-tmpfiles-setup.service"] ++ lib.optional minted "vci-token.service";
      # `nix eval` of a git+file flake runs git itself, from PATH.
      path = [pkgs.git];
      environment = {
        HOME = state;
        XDG_CACHE_HOME = "${state}/.cache";
        NIX_REMOTE = "daemon";
        # Plain errors in builds.jsonl and the journal.
        NO_COLOR = "1";
      };
      serviceConfig =
        {
          Type = "simple";
          ExecStart = lib.escapeShellArgs args;
          Restart = "always";
          RestartSec = "30s";
          User = "vci";
          Group = "vci";
          SupplementaryGroups = ["prometheus-textfile"];
          StateDirectory = "vci";
          StateDirectoryMode = "0755";
          # node_exporter (its own user) and operators read what is written.
          UMask = "0022";
          # A desktop shares this host: evaluations yield to everything else.
          Nice = 19;
          CPUSchedulingPolicy = "idle";
          IOSchedulingClass = "idle";
          MemoryMax = cfg.memoryMax;
          ProtectSystem = "strict";
          ReadWritePaths = [state textfileDir];
          ProtectHome = true;
          PrivateTmp = true;
          PrivateDevices = true;
          ProtectProc = "invisible";
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          ProtectControlGroups = true;
          NoNewPrivileges = true;
          RestrictSUIDSGID = true;
          LockPersonality = true;
        }
        // lib.optionalAttrs (cfg.statusTokenFile != null) {
          LoadCredential = ["status-token:${cfg.statusTokenFile}"];
        };
    };
  };
}
