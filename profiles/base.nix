# Base Profile
# Common modules shared by all hosts
{
  config,
  lib,
  pkgs,
  inputs,
  settings,
  ...
}: {
  imports = [
    # CLI Tools — the headless-safe set. The seat-bound rest is in profiles/cli-desktop.nix,
    # imported by profiles/desktop.nix; see that file's header for the boundary.
    ../profiles/cli-core.nix

    # Core NixOS Configuration
    ../features/nixos
    ../features/nixos/auto-update
    ../features/nixos/bluetooth
    ../features/nixos/boot
    ../features/nixos/docker
    ../features/nixos/fonts
    ../features/nixos/graphics
    ../features/nixos/networking
    ../features/nixos/networking/dns.nix
    ../features/nixos/networking/firewall.nix
    ../features/nixos/security/no-defaults
    ../features/nixos/security/sudo
    ../features/nixos/systemd
    ../features/nixos/sound
    ../features/nixos/users

    # Performance Optimization
    ../features/performance/environment
    ../features/performance/hardware
    ../features/performance/filesystems
    ../features/performance/memory

    # Security
    ../features/security/apparmor
    ../features/security/keepassxc
    ../features/security/pam
    ../features/security/veracrypt
    ../features/security/yubikey

    # Anduril NixOS STIG V1R3 — the OPTION SURFACE ONLY, deliberately.
    #
    # The control modules are no longer host-wide. The baseline now lives on mimir
    # alone, which imports profiles/base-safe.nix directly; see ADR-0004 for the
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
    # control modules imported the report scores the host against profile "none"
    # and renders every control "Not Implemented", which is the honest answer and
    # the one bin/ci/stig already treats as a documented decision rather than a
    # CAT I regression.
    ../features/security/stig/default.nix

    # Controls satisfied by the fleet's disk layout rather than by a control module. Carried
    # by every host because the property is true of every host, independently of which
    # baseline it imports — see that file's header and ADR-0004.
    ../features/security/stig/profiles/external-evidence.nix

    # Storage
    ../features/storage/qdirstat

    # VPN
    #../features/network/mullvad

    # Network Browsers
    ../features/network/chromium
    ../features/network/firefox
    ../features/network/searx

    # Media (common to all hosts)
    ../features/media/calibre
    ../features/media/qbittorrent
    ../features/media/spotify
    ../features/media/vlc
  ];
}
