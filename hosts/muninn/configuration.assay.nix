# Colocated suite for hosts/muninn/configuration.nix — evaluated selection, not source text.
let
  assay = import ../../common/assay/default.nix;
  nixos = import ../../common/assay/nixos.nix;
  features = import ../../lib/features.nix {inherit (nixos) lib;};
  cfg = features.evalSelection {
    modules = [
      ./configuration.nix
      {disabledModules = [./disko.nix ./filesystems.nix ./hardware.nix];}
    ];
  };
  has = f: builtins.elem f (features.enabledFeatures cfg);

  # The STIG posture is read off the full evaluated host, built through lib/mk-host.nix as
  # flake.nix does: the selection above cannot see what a profile's imports switch on.
  mkHost = import ../../lib/mk-host.nix {inputs = nixos.flakeInputs;};
  muninn = mkHost "muninn";
  host = muninn.config;
  # The one-option rollback: the same host with Secure Boot turned off again.
  rolledBack = (muninn.extendModules {modules = [{features.hardening.secureBoot.enable = nixos.lib.mkForce false;}];}).config;
  inherit (host.security) stig;
  manifest = import ../../features/security/stig/lib/manifest.nix;
  accountedFor = stig.implemented ++ builtins.attrNames stig.exclude ++ builtins.attrNames stig.satisfiedExternally;
  sorted = builtins.sort (a: b: a < b);
  hasPamLine = service: module: builtins.match ".*${module}.*" host.security.pam.services.${service}.text != null;
in
  assay.suite "configuration" {
    enablesFleetAccess = assay.eq (has "fleet.remote-access") true;
    enablesAi = assay.eq cfg.profiles.ai.enable true;
    # muninn is the monitoring standby for when mimir is down.
    monitoringStandby = assay.eq [(has "monitoring.prometheus") (has "monitoring.grafana")] [true true];
    noRelay = assay.eq (has "fleet.remote-desktop-relay") false;
    # Work laptop: no personal files, so no NFS client for mimir's /data.
    noNfsClient = assay.eq (has "storage.nfs-client") false;

    # muninn is the STIG test host (ADR-0008): every one of the 103 controls is configured,
    # excluded in writing, or covered by external evidence, each exactly once.
    enablesStigTestHost = assay.eq (has "security.stig.profiles.test-host") true;
    stigProfileIsTestHost = assay.eq [stig.enable stig.profile] [true "test-host"];
    stigAccountsForExactlyTheManifest = assay.eq (sorted accountedFor) (sorted manifest.ids);
    stigCountsAre83Configured19Excluded1External =
      assay.eq [(builtins.length stig.implemented) (builtins.length (builtins.attrNames stig.exclude)) (builtins.attrNames stig.satisfiedExternally)] [83 19 ["V-268144"]];
    stigExclusionsAreWritten =
      assay.eq (builtins.filter (id: builtins.stringLength stig.exclude.${id} <= 80) (builtins.attrNames stig.exclude)) [];

    # A merge to main reaches this laptop without anyone at it, so what keeps it reachable
    # and usable is pinned on the evaluated host. Each line is a control the profile
    # excludes; carrying one by accident fails here before it fails on the machine.
    #
    # The operator's sudo stays passwordless (features/fleet/operator-ssh.nix), which is what
    # the deployer activates through: V-268156 and V-268155 change the wheel rule and the
    # credential cache, not this rule.
    operatorKeepsPasswordlessSudo =
      assay.eq (builtins.any (r: r.users == ["tom"] && builtins.any (c: c.command == "ALL" && c.options == ["NOPASSWD"]) r.commands) host.security.sudo.extraRules) true;
    sshStaysKeyOnlyWithTheOperatorKeys =
      assay.eq [host.services.openssh.settings.PasswordAuthentication (builtins.length host.users.users.tom.openssh.authorizedKeys.keys > 0)] [false true];
    wifiStaysUp = assay.eq [host.networking.networkmanager.enable host.networking.wireless.enable] [true true]; # V-268146
    bluetoothStaysOn = assay.eq host.hardware.bluetooth.enable true; # V-268147
    usersStayMutable = assay.eq host.users.mutableUsers true; # V-268138
    noUsbguardWithoutAPolicy = assay.eq host.services.usbguard.enable false; # V-268139
    noTokenModuleInTheLoginStacks = assay.eq host.security.pam.p11.enable false; # V-268177, V-268179
    # V-268081 and V-268170 are excluded because their PAM lines do not enforce anything
    # (ADR-0008). The rendered stacks carry neither line until the modules are reworked.
    noFaillockLineInLoginOrSshd = assay.eq (map (s: hasPamLine s "pam_faillock") ["login" "sshd"]) [false false];
    noPwqualityLineInPasswordStacks = assay.eq (map (s: hasPamLine s "pam_pwquality") ["passwd" "chpasswd" "sudo"]) [false false false];
    noFipsOnTheKernelCommandLine = assay.eq (builtins.elem "fips=1" host.boot.kernelParams) false; # V-268168
    # GH-184: muninn boots through lanzaboote (signed UKIs), not the Python systemd-boot
    # installer, through our all-profiles install hook (comin's system-profiles/comin).
    secureBootOn = assay.eq host.features.hardening.secureBoot.enable true;
    bootsThroughLanzaboote =
      assay.eq [host.boot.lanzaboote.enable host.boot.loader.systemd-boot.enable host.boot.loader.external.enable] [true false true];
    lanzabooteUsesTheAllProfilesHook =
      assay.eq (builtins.match ".*/bin/lzbt-all-profiles" host.boot.loader.external.installHook != null) true;
    lanzabooteKeysInSbctl = assay.eq host.boot.lanzaboote.pkiBundle "/var/lib/sbctl";
    # The keys are created on muninn (GH-343), backed up encrypted to the operators.
    createsItsKeys = assay.eq [host.features.hardening.secureBoot.createKeys.enable (host.systemd.services ? sbctl-keys)] [true true];
    backupGoesToTheOperators = assay.eq (builtins.length host.features.hardening.secureBoot.createKeys.recipients > 0) true;
    # Rolled back, the key unit goes too (the keys and the backup stay on disk).
    rollbackDropsTheKeyUnit = assay.eq (rolledBack.systemd.services ? sbctl-keys) false;
    # Rollback is one option: off again, and the Python installer is back, lanzaboote gone.
    secureBootRollsBackWithOneOption =
      assay.eq [rolledBack.boot.loader.systemd-boot.enable rolledBack.boot.lanzaboote.enable rolledBack.boot.loader.external.enable] [true false false];
    timeServersAreNotPinned = assay.eq (builtins.any (s: builtins.match ".*navy\\.mil" s != null) host.networking.timeServers) false; # V-268149

    # /etc on the overlay, mutable, state carried across (GH-185).
    etcOnTheOverlay = assay.eq (has "nixos.etc-overlay") true;
    # Rollback: lib.mkForce false turns it off; that generation carries the state back out
    # (features/nixos/etc-overlay/default.assay.nix rollbackCarriesOut, and the VM gate).
    etcOverlayRollsBack = let
      off = features.evalSelection {
        modules = [
          ./configuration.nix
          {disabledModules = [./disko.nix ./filesystems.nix ./hardware.nix];}
          {features.nixos.etc-overlay.enable = nixos.lib.mkForce false;}
        ];
      };
    in
      assay.eq (builtins.elem "nixos.etc-overlay" (features.enabledFeatures off)) false;
  }
