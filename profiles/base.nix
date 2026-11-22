# Base Profile
# Common modules shared by all hosts
{
  config,
  lib,
  ...
}: let
  fleet = import ../common/fleet.nix;
in {
  options.profiles.base.enable = lib.mkEnableOption "the base profile";

  config = lib.mkIf config.profiles.base.enable {
    # CLI Tools — the headless-safe set. The seat-bound rest is in profiles/cli-desktop.nix,
    # enabled by profiles/desktop.nix; see that file's header for the boundary.
    profiles.cli-core.enable = true;

    # Core NixOS Configuration
    features.nixos.enable = true;
    features.nixos.auto-update.enable = true;
    features.nixos.bluetooth.enable = true;
    features.nixos.boot.enable = true;
    features.nixos.docker.enable = true;
    features.nixos.fonts.enable = true;
    features.nixos.graphics.enable = true;
    features.nixos.networking.enable = true;
    features.nixos.networking.dns.enable = true;
    features.nixos.networking.firewall.enable = true;
    features.nixos.security.no-defaults.enable = true;
    features.nixos.security.sudo.enable = true;
    features.nixos.systemd.enable = true;
    features.nixos.sound.enable = true;
    features.nixos.users.enable = true;

    # Store maintenance is the Voltaic tools' (rust/tools/vgc, rust/tools/vopt), in place of
    # nix-collect-garbage and auto-optimise-store. Rollback, per host or here:
    #   features.nixos.vgc.enable = lib.mkForce false;   # stock nix.gc back
    #   features.nixos.vopt.enable = lib.mkForce false;  # inline auto-optimise-store back
    features.nixos.vgc.enable = true;
    features.nixos.vopt.enable = true;

    # Substitute from the fleet's vcache servers (common/fleet.nix binaryCaches) first.
    # Rollback: features.nix.vcache.client.enable = lib.mkForce false;
    features.nix.vcache.client.enable = true;

    # Push this host's builds to the fleet cache (features/nix/vpush), automatically, on
    # every builder-role host that is not a cache (common/fleet.nix `pushesToCache`): the
    # post-build-hook is the default path into vcache. Off on the cache (drakkar).
    # Rollback: features.nix.vpush.enable = lib.mkForce false;
    features.nix.vpush.enable = lib.mkDefault (fleet.pushesToCache (config.networking.hostName or ""));

    # Build every fleet host for main and the open PRs (features/nix/vci, GH-242) on the cache
    # host (common/fleet.nix `isCacheIn`), whose store vcache serves: a built commit is in the
    # cache with nothing pushed, so deploys only substitute. Off everywhere else.
    # Rollback: features.nix.vci.enable = lib.mkForce false;
    features.nix.vci.enable = lib.mkDefault (fleet.isCacheIn fleet.hosts (config.networking.hostName or ""));

    # Performance Optimization
    features.performance.environment.enable = true;
    features.performance.hardware.enable = true;
    features.performance.filesystems.enable = true;
    features.performance.memory.enable = true;

    # Security
    features.security.apparmor.enable = true;
    features.security.keepassxc.enable = true;
    features.security.pam.enable = true;
    features.security.veracrypt.enable = true;
    features.security.yubikey.enable = true;

    # Anduril NixOS STIG V1R3 — the OPTION SURFACE ONLY, deliberately.
    #
    # The control modules are no longer host-wide. The baseline now lives on mimir
    # alone, which enables the base-safe control set directly; see ADR-0004 for the
    # decision and docs/security/stig-triage.md for the per-control classification.
    #
    # Why it moved: the audit set is not free on an interactive machine. The
    # syscall rules cover the chmod/chown/open/rename/unlink families, so every
    # nix build, every git operation and every game launch generates records. On
    # drakkar — the desktop and gaming station — that was observable as stalls.
    # 6f5e7011 raised audit_backlog_limit to 65536 to stop them, which treated the
    # symptom: the records were still being generated and enqueued, just into a
    # bigger buffer. The fix is not to audit a workstation at all.
    #
    # What stays is default.nix, which declares `security.stig.*` and configures
    # nothing by itself (its only `config` stanzas are conditional on pwquality
    # being set and on audit already being enabled). It must stay on EVERY host:
    # flake.nix builds `stigReport.<host>` for all four from
    # `nixosConfigurations.<host>.config.security.stig`, so dropping the option
    # surface would make `nix build .#stigReport.drakkar` fail to EVALUATE rather
    # than report an unhardened host — an error where a finding belongs. With no
    # control modules enabled the report scores the host against profile "none"
    # and renders every control "Not Implemented", which is the honest answer and
    # the one bin/ci/stig already treats as a documented decision rather than a
    # CAT I regression.
    features.security.stig.enable = true;

    # Controls satisfied by the fleet's disk layout rather than by a control module. Carried
    # by every host because the property is true of every host, independently of which
    # baseline it enables — see that file's header and ADR-0004.
    features.security.stig.profiles.external-evidence.enable = true;

    # Storage
    features.storage.qdirstat.enable = true;

    # VPN
    # features.network.mullvad.enable = true;

    # Network Browsers
    features.network.chromium.enable = true;
    features.network.firefox.enable = true;
    features.network.searx.enable = true;

    # Media (common to all hosts)
    features.media.calibre.enable = true;
    features.media.qbittorrent.enable = true;
    features.media.spotify.enable = true;
    features.media.vlc.enable = true;
  };
}
