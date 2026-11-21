# Boot loader, kernel hardening and the physical-access options (ADR-0007).
#
# The fleet-wide kernel and network hardening lives here, as boot.kernel.sysctl and
# boot.blacklistedKernelModules. It used to sit in boot.kernelParams as strings like
# "net.ipv4.conf.all.accept_redirects=0". The kernel never treats a bare sysctl name on the
# command line as a sysctl. It only reads "sysctl.<name>=", and the rest go to init as
# unused arguments. So none of those settings ever reached a host. Each sysctl below was
# checked against a mixed desktop/gaming/server fleet, and ADR-0007 lists what was left out
# and why.
#
# Settings that are STIG controls (kptr_restrict, randomize_va_space, tcp_syncookies) are
# not set here. ADR-0003 makes the STIG modules their only source.
#
# Secure Boot and TPM2 unlock need someone at the machine (key enrollment, a TPM PCR
# binding), so they ship as options that default to OFF. The runbooks are in ADR-0007.
#
# The lanzaboote module (flake input, GH-184) is imported here, on every host that has the
# input, and stays inert until features.hardening.secureBoot.enable turns it on. An
# evaluation without the input (inputs.lanzaboote absent or null) still gets the option,
# and the assertion below refuses to turn it on there. The reboot/rollback VM test is
# ./test.nix (checks.x86_64-linux.lanzaboote-vm).
{
  config,
  lib,
  options,
  inputs,
  pkgs,
  ...
}: let
  cfg = config.features.hardening;

  # Network protocols nothing in this fleet uses. Their modules have had a history of
  # remotely or locally reachable bugs, and an unprivileged socket() call is enough to
  # autoload them. `blacklist` only stops that autoloading; root can still `modprobe` one
  # explicitly.
  # sctp is safe to list: WebRTC (browsers, Discord, Steam voice) uses the userspace usrsctp
  # stack, not the kernel module. can and atm cover hardware no host has.
  unusedNetworkProtocols = [
    "dccp"
    "sctp"
    "rds"
    "tipc"
    "n-hdlc"
    "ax25"
    "netrom"
    "x25"
    "rose"
    "decnet"
    "econet"
    "af_802154"
    "ipx"
    "appletalk"
    "psnap"
    "p8023"
    "p8022"
    "can"
    "atm"
  ];

  hasLanzaboote = options ? boot && options.boot ? lanzaboote;
  lanzaboote = inputs.lanzaboote or null;
in {
  imports = lib.optional (lanzaboote != null) lanzaboote.nixosModules.lanzaboote;

  options.features.hardening = {
    secureBoot = {
      enable = lib.mkEnableOption ''
        UEFI Secure Boot through lanzaboote, which replaces the Python systemd-boot
        installer with lzbt (signed UKIs on the ESP). OFF by default. The keys must exist
        in pkiBundle (`sudo sbctl create-keys`) BEFORE the first deploy with this on, or
        the bootloader install fails and the switch with it. Secure Boot itself stays off
        in firmware until the keys are enrolled at the machine; the signed images boot
        either way. See ADR-0007, "Runbook: Secure Boot"'';

      pkiBundle = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/sbctl";
        description = "Where `sbctl create-keys` put the Secure Boot keys.";
      };
    };

    tpm2Unlock.enable = lib.mkEnableOption ''
      unlocking the LUKS root (cryptroot) with the TPM2 chip, through systemd-cryptenroll.
      OFF by default: the TPM has to be enrolled on the machine itself
      (systemd-cryptenroll), and an unenrolled TPM token only adds a timeout before the
      passphrase prompt. The passphrase keeps working as a fallback. See ADR-0007, "Runbook: TPM2 unlock"'';
  };

  config = lib.mkMerge [
    {
      boot = {
        loader = {
          systemd-boot = {
            enable = lib.mkDefault true;
            configurationLimit = 10;
            # The editor stays ON while Secure Boot is off. It is the recovery path for a
            # locked root (ADR-0007, "Recovery"): appending
            # systemd.setenv=SYSTEMD_SULOGIN_FORCE=1 opens an emergency shell. Turning it off
            # without Secure Boot buys nothing. The root filesystem is LUKS, so an edited
            # command line still stops at the passphrase prompt, and anyone with physical
            # access can rewrite the unsigned ESP anyway.
          };
          efi = {
            canTouchEfiVariables = true;
          };
        };

        kernelParams = [
          # Performance kernel parameters
          "transparent_hugepage=always"
          "elevator=deadline"
          # The CPU governor is set by powerManagement.cpuFreqGovernor in
          # features/performance/hardware, its single owner.

          # NOTE: the entries below are NOT applied. They are sysctl names, and the kernel
          # ignores them on its command line (see the header). Moving the network and fs
          # ones into boot.kernel.sysctl is a follow-up for the performance owner.
          # `elevator=` has also done nothing since Linux 5.0. Memory writeback and swap are
          # set as real sysctls in features/performance/memory, their single owner.

          # Network performance optimization
          "net.core.rmem_max=16777216"
          "net.core.wmem_max=16777216"
          "net.core.netdev_max_backlog=5000"
          "net.ipv4.tcp_congestion_control=bbr"

          # File system performance optimization
          "fs.file-max=2097152"
          "fs.inotify.max_user_watches=524288"
        ];

        # mkDefault throughout, so a host with a real reason can override one key without a
        # conflicting-definition error.
        kernel.sysctl = lib.mapAttrs (_: lib.mkDefault) {
          # Kernel log (addresses, driver state) readable only with CAP_SYSLOG. Wheel can
          # still read it through `journalctl -k`.
          "kernel.dmesg_restrict" = 1;
          # No eBPF for unprivileged users, and the JIT hardened against spraying. Nothing
          # on these hosts loads BPF without root. Steam, Wine and Docker don't.
          "kernel.unprivileged_bpf_disabled" = 1;
          "net.core.bpf_jit_harden" = 2;

          # No host here is a router. Ignore ICMP redirects and source-routed packets, and
          # don't send redirects. Docker and Tailscale forward, but never back out the
          # interface a packet came in on, which is the only case send_redirects covers.
          "net.ipv4.conf.all.accept_redirects" = 0;
          "net.ipv4.conf.default.accept_redirects" = 0;
          "net.ipv4.conf.all.secure_redirects" = 0;
          "net.ipv4.conf.default.secure_redirects" = 0;
          "net.ipv4.conf.all.send_redirects" = 0;
          "net.ipv4.conf.default.send_redirects" = 0;
          "net.ipv6.conf.all.accept_redirects" = 0;
          "net.ipv6.conf.default.accept_redirects" = 0;
          "net.ipv4.conf.all.accept_source_route" = 0;
          "net.ipv4.conf.default.accept_source_route" = 0;
          "net.ipv6.conf.all.accept_source_route" = 0;
          "net.ipv6.conf.default.accept_source_route" = 0;
          "net.ipv4.conf.all.log_martians" = 1;
          "net.ipv4.conf.default.log_martians" = 1;
          # RFC 1337: drop RSTs for sockets in TIME-WAIT (TIME-WAIT assassination).
          "net.ipv4.tcp_rfc1337" = 1;
        };

        blacklistedKernelModules = unusedNetworkProtocols;

        # ZFS root pool import behavior
        # Setting this explicitly to adopt the safer 26.11+ default.
        # - false (26.11+ default, RECOMMENDED): Requires manual intervention if pool was last imported elsewhere
        #   → Safer: Prevents accidental corruption from dual-imports
        # - true (old default): Force-imports ZFS root pool even if previously mounted elsewhere
        #   → Risk: Can cause data corruption if pool was active on another machine
        # Note: Currently no fleet hosts use ZFS (all use btrfs), but setting this proactively
        # ensures safety if ZFS is added later. Use kernel param `zfs_force=1` on unclean shutdowns.
        zfs = {
          forceImportRoot = false;
        };
      };
    }

    # mkMerge, not `//`: the right-hand `boot.lanzaboote` used to replace the whole `boot`
    # attrset on the left, so systemd-boot was never turned off and the editor stayed on.
    # Nothing noticed while the lanzaboote module was absent (GH-184).
    (lib.mkIf cfg.secureBoot.enable (lib.mkMerge [
      {
        assertions = [
          {
            assertion = hasLanzaboote;
            message = ''
              features.hardening.secureBoot.enable needs the lanzaboote NixOS module, which
              this evaluation does not have: features/nixos/boot imports it from
              inputs.lanzaboote (the flake input), and that is absent or null here
              (ADR-0007, "Runbook: Secure Boot").
            '';
          }
        ];
        # lanzaboote replaces systemd-boot's installer with its own, which signs the UKIs.
        boot.loader.systemd-boot.enable = lib.mkForce false;
        # With signed UKIs the command line is part of what's signed. Leaving the editor on
        # would defeat the measurement.
        boot.loader.systemd-boot.editor = false;
        # `sbctl verify` (is everything on the ESP signed?) and `sbctl status`.
        environment.systemPackages = [pkgs.sbctl];
      }
      (lib.optionalAttrs hasLanzaboote {
        boot.lanzaboote = {
          enable = true;
          inherit (cfg.secureBoot) pkiBundle;
        };
      })
    ]))

    (lib.mkIf cfg.tpm2Unlock.enable {
      security.tpm2.enable = true;
      # nixpkgs 26.11 only has the systemd initrd, so all this adds is the TPM2 token
      # plugin and the crypttab option.
      boot.initrd.systemd.tpm2.enable = true;
      boot.initrd.luks.devices.cryptroot.crypttabExtraOpts = ["tpm2-device=auto"];
    })
  ];
}
