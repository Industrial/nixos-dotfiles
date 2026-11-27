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
  settings ? {},
  ...
}: let
  cfg = config.features.hardening;
  fleet = import ../../../common/fleet.nix;
  sb = cfg.secureBoot;
  createKeys = sb.enable && sb.createKeys.enable;

  # The Secure Boot keys, created on the host when they are missing (createKeys, GH-184,
  # GH-343). Idempotent: it does nothing when db.key exists, and it refuses, rather than
  # overwrites, when keys/ exists without db.key (a partial or foreign bundle). Run by the
  # install hook BEFORE lzbt, because switch-to-configuration installs the bootloader before
  # it activates, so a unit would come too late for the first switch; and by
  # sbctl-keys.service at boot and on every switch.
  ensureKeys = pkgs.writeShellApplication {
    name = "sbctl-ensure-keys";
    runtimeInputs = [pkgs.sbctl pkgs.coreutils pkgs.util-linux];
    text = ''
      bundle=${lib.escapeShellArg sb.pkiBundle}
      # One at a time: under vdeploy the unit starts in the `test` step and the hook runs in
      # the `boot` step; neither may see the other's half-written keys/.
      exec 9>/run/sbctl-ensure-keys.lock
      flock 9
      if [ -s "$bundle/keys/db/db.key" ]; then
        exit 0
      fi
      if [ -e "$bundle/keys" ]; then
        echo "sbctl-ensure-keys: $bundle/keys exists but has no db/db.key; refusing to create keys over it" >&2
        exit 1
      fi
      install -d -m 0700 "$bundle"
      sbctl create-keys --database-path "$bundle/GUID" --export "$bundle/keys"
      chmod -R go-rwx "$bundle"
      test -s "$bundle/keys/db/db.key"
      echo "sbctl-ensure-keys: created the Secure Boot keys in $bundle" >&2
    '';
  };

  # The encrypted backup of pkiBundle: tar | age to the operator ssh-ed25519 keys. Written
  # once, when it is missing; the keys never change, so neither does the backup. No new key
  # material and no passphrase: any operator key in common/fleet.nix decrypts it.
  backupFile = "${sb.createKeys.backupDirectory}/sbctl-${config.networking.hostName}.tar.age";
  recipients = pkgs.writeText "sbctl-backup-recipients" (lib.concatLines sb.createKeys.recipients);
  backupKeys = pkgs.writeShellApplication {
    name = "sbctl-backup-keys";
    runtimeInputs = [pkgs.age pkgs.gnutar pkgs.coreutils];
    text = ''
      bundle=${lib.escapeShellArg sb.pkiBundle}
      dir=${lib.escapeShellArg sb.createKeys.backupDirectory}
      out=${lib.escapeShellArg backupFile}
      test -s "$bundle/keys/db/db.key"
      install -d -m 0755 "$dir"
      if [ ! -s "$out" ]; then
        tar -C "$(dirname "$bundle")" -cf - "$(basename "$bundle")" | age -R ${recipients} -o "$out.tmp"
        sync "$out.tmp"
        mv -f "$out.tmp" "$out"
        echo "sbctl-backup-keys: wrote $out" >&2
      fi
      chown ${lib.escapeShellArg sb.createKeys.backupOwner} "$out"
      chmod 0400 "$out"
    '';
  };

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

  # The bootloader install hook used when Secure Boot is on, in place of upstream's
  # (GH-184). It does what the Python systemd-boot installer does that upstream's does not:
  #  - It gives lzbt the generations of EVERY system profile: system-*-link (nixos-rebuild,
  #    deploy-rs) and system-profiles/<name>-<N>-link (comin). A link lzbt cannot parse is
  #    skipped with a warning; lzbt itself would fail on it.
  #  - It makes the generation being switched to ($1, the toplevel from
  #    switch-to-configuration) the boot default. It finds the UKI whose .cmdline carries
  #    init=<toplevel>/init, the highest version if several do, and writes
  #    `default <that file>` into loader.conf (temp file, fsync, rename). lzbt alone
  #    leaves `default nixos-*`, which picks the highest version number, and a stale
  #    high-numbered profile wins that.
  lzbtAllProfiles = let
    lz = config.boot.lanzaboote;
    esp = config.boot.loader.efi.efiSysMountPoint;
  in
    pkgs.writeShellApplication {
      name = "lzbt-all-profiles";
      runtimeInputs = [pkgs.coreutils pkgs.gnugrep];
      text = ''
        toplevel=$(readlink -f "$1")
        esp=${lib.escapeShellArg esp}

        shopt -s nullglob
        links=()
        for link in /nix/var/nix/profiles/system-*-link /nix/var/nix/profiles/system-profiles/*-link; do
          if [[ ''${link##*/} =~ ^[^-]+-[0-9]+-link$ ]]; then
            links+=("$link")
          else
            echo "lzbt-all-profiles: skipping $link (not <profile>-<N>-link)" >&2
          fi
        done

        ${lib.optionalString createKeys "${ensureKeys}/bin/sbctl-ensure-keys"}

        PATH=${config.systemd.package}/lib/systemd:$PATH
        ${lz.installCommand} \
          ${lib.escapeShellArgs ["--public-key=${toString lz.publicKeyFile}" "--private-key=${toString lz.privateKeyFile}"]} \
          "$esp" "''${links[@]}"

        matches=()
        for uki in "$esp"/EFI/Linux/nixos-generation-*.efi; do
          if grep -qaF -- "init=$toplevel/init" "$uki"; then
            matches+=("''${uki##*/}")
          fi
        done
        if [ "''${#matches[@]}" -eq 0 ]; then
          echo "lzbt-all-profiles: no UKI boots $toplevel; loader.conf keeps its default" >&2
          exit 0
        fi
        entry=$(printf '%s\n' "''${matches[@]}" | sort -V | tail -n 1)

        conf="$esp/loader/loader.conf"
        { grep -v '^default ' "$conf" || true; echo "default $entry"; } > "$conf.tmp"
        sync "$conf.tmp"
        mv -f "$conf.tmp" "$conf"
        sync "$conf"
        echo "lzbt-all-profiles: boot default is $entry" >&2
      '';
    };
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

      createKeys = {
        enable = lib.mkEnableOption ''
          creating the Secure Boot keys on the host when they are missing (GH-184, GH-343):
          `sbctl create-keys` into pkiBundle (root, 0700), from the install hook before lzbt
          signs and from sbctl-keys.service. Never overwrites existing keys. Also writes an
          age-encrypted backup of pkiBundle to the operator keys. Only takes effect with
          secureBoot.enable. See ADR-0007, "Runbook: Secure Boot"'';

        recipients = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = fleet.operatorKeys;
          defaultText = lib.literalExpression "(import common/fleet.nix).operatorKeys";
          description = "age recipients (ssh-ed25519 public keys) the backup is encrypted to.";
        };

        backupDirectory = lib.mkOption {
          type = lib.types.str;
          default = "/var/lib/sbctl-backup";
          description = "Where the encrypted backup, sbctl-<host>.tar.age, is written.";
        };

        backupOwner = lib.mkOption {
          type = lib.types.str;
          default = settings.username or "tom";
          description = "The operator who owns (and can copy off-host) the encrypted backup.";
        };
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
      (lib.mkIf createKeys {
        assertions = [
          {
            assertion = sb.createKeys.recipients != [];
            message = "features.hardening.secureBoot.createKeys needs at least one backup recipient.";
          }
        ];
        # Keys (if missing), then the backup (if missing). Also at boot, so a backup removed
        # by hand comes back; the keys themselves are never rewritten.
        systemd.services.sbctl-keys = {
          description = "Secure Boot keys: create if missing, back up encrypted to the operators";
          wantedBy = ["multi-user.target"];
          restartTriggers = [ensureKeys backupKeys];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            UMask = "0077";
            ExecStart = ["${ensureKeys}/bin/sbctl-ensure-keys" "${backupKeys}/bin/sbctl-backup-keys"];
          };
        };
      })
      (lib.optionalAttrs hasLanzaboote {
        boot.lanzaboote = {
          enable = true;
          inherit (cfg.secureBoot) pkiBundle;
        };
        # Upstream's hook only sees /nix/var/nix/profiles/system-*-link and leaves
        # `default nixos-*` (highest version wins). comin deploys through
        # system-profiles/comin, so on drakkar that made a stale system-493 the boot
        # default. This hook, below, fixes both.
        boot.loader.external.installHook = lib.mkForce "${lzbtAllProfiles}/bin/lzbt-all-profiles";
        assertions = [
          {
            # The hook below runs one lzbt install on the main ESP, without the pcrlock
            # prediction. Those upstream features would need porting first.
            assertion = config.boot.lanzaboote.extraEfiSysMountPoints == [] && !config.boot.lanzaboote.measuredBoot.enable;
            message = "features/nixos/boot's lanzaboote install hook supports neither extraEfiSysMountPoints nor measuredBoot.";
          }
        ];
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
