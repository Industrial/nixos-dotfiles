# vci (rust/tools/vci, GH-242): the fleet's CI on the cache host. Every `interval` it lists
# main and the open same-repository PRs (`git ls-remote`, and GitHub's open-PR list read
# without a token), and builds the next unbuilt head commit for every fleet host:
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
# (#243) starts from.
#
# GitHub commit statuses are OFF by default, and the CI result on PRs stays GitHub
# Actions'. `statusTokenFile` (a root-only file, handed to the unit with LoadCredential,
# so the vci user reads it only from its credentials directory) turns them on: context
# `vci/<host>`, pending then success/failure. The file is read at every post, so whatever
# mints the token can replace it: the intended source is the GitHub App the user is
# creating for vbump (#189, #228), with "Commit statuses: read and write" added. No secret
# is provisioned here.
#
# Runs as its own static user `vci`: allowed to use the Nix daemon (never trusted-users),
# niced to idle CPU and I/O, memory-capped for the evaluations (`memoryMax`), file system
# read-only except its state and the textfile directory. Builds run in the daemon's
# sandbox as nixbld users, as any user's builds do.
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
  state = "/var/lib/vci";
  restricted = lib.attrByPath ["features" "nixos" "users" "enable"] false config || cfg.restrictedNixUsers;
  args =
    ["${vci}/bin/vci"]
    ++ lib.concatMap (h: ["--host" h]) cfg.hosts
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
    ]
    ++ lib.optional (!cfg.pulls) "--no-pulls"
    ++ lib.optionals (cfg.pullsUrl != null) ["--pulls-url" cfg.pullsUrl]
    ++ lib.optionals (cfg.statusTokenFile != null) ["--status-token-file" "%d/status-token"];
in {
  imports = [../../monitoring/textfile-collector.nix];

  options.features.nix.vci = {
    hosts = mkOption {
      type = types.listOf types.str;
      default = fleet.order;
      defaultText = lib.literalExpression "(import common/fleet.nix).order";
      description = "The nixosConfigurations to build for every commit: the fleet's hosts.";
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
    restrictedNixUsers = mkOption {
      type = types.bool;
      default = false;
      description = "Set where nix.settings.allowed-users is restricted by something other than features/nixos/users (a test); then `vci` is added to it.";
    };
  };

  config = {
    environment.systemPackages = [vci];

    users.users.vci = {
      isSystemUser = true;
      group = "vci";
      home = state;
      description = "vci, the fleet's CI builds";
    };
    users.groups.vci = {};
    # It may use the Nix daemon (never trusted-users), merged into the host's list.
    nix.settings.allowed-users = lib.mkIf restricted ["vci"];

    systemd.services.vci = {
      description = "vci: every fleet host built for main and open PRs, into the cache's store";
      wantedBy = ["multi-user.target"];
      wants = ["network-online.target"];
      after = ["network-online.target" "nix-daemon.socket" "systemd-tmpfiles-setup.service"];
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
