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
  host = (mkHost "muninn").config;
  inherit (host.security) stig;
  manifest = import ../../features/security/stig/lib/manifest.nix;
  accountedFor = stig.implemented ++ builtins.attrNames stig.exclude ++ builtins.attrNames stig.satisfiedExternally;
  sorted = builtins.sort (a: b: a < b);
  # The rendered PAM file of a service matches a regex. `[^\n]*` keeps a match on one line,
  # so a pattern spanning "\n" pins that two lines are adjacent and in that order.
  pamMatches = service: regex: builtins.match regex host.security.pam.services.${service}.text != null;
  faillockPolicy = "deny=3 fail_interval=900";
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
    stigCountsAre85Configured17Excluded1External =
      assay.eq [(builtins.length stig.implemented) (builtins.length (builtins.attrNames stig.exclude)) (builtins.attrNames stig.satisfiedExternally)] [85 17 ["V-268144"]];
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
    # V-268081 and V-268170 are carried (ADR-0008). What is pinned is the lines that ENFORCE,
    # in the order that makes them enforce: a pam_faillock or pam_pwquality line being present
    # is what these controls once had while doing nothing. That the stacks below lock an
    # account and refuse a weak password on this host's configuration is the VM gate
    # features/security/stig/tests/test-host-logon.nix.
    #
    # login: preauth ahead of the first pam_unix; authfail directly behind the `sufficient`
    # pam_unix, ending the stack; the account line that clears the tally after a success.
    loginRefusesALockedAccountBeforeAskingForAPassword = assay.eq [
      (pamMatches "login" ".*\nauth required [^\n]*pam_faillock\\.so preauth audit ${faillockPolicy} silent unlock_time=0[^\n]*\nauth [^\n]*pam_unix\\.so.*")
      # No pam_unix auth line anywhere ahead of it.
      (pamMatches "login" ".*\nauth [^\n]*pam_unix\\.so.*\nauth required [^\n]*pam_faillock\\.so preauth.*")
    ] [true false];
    loginRecordsAFailureRightBehindPamUnix =
      assay.eq (pamMatches "login" ".*\nauth sufficient [^\n]*pam_unix\\.so[^\n]*\nauth \\[default=die] [^\n]*pam_faillock\\.so authfail audit ${faillockPolicy} unlock_time=0[^\n]*\n.*") true;
    loginClearsTheTallyOnSuccess =
      assay.eq (pamMatches "login" ".*\naccount required [^\n]*pam_faillock\\.so[^\n]*\naccount required [^\n]*pam_unix\\.so.*") true;
    # The greeter and the lock screen get all of that through `login`, and add nothing.
    graphicalLogonUsesTheLoginStack =
      assay.eq [(pamMatches "gdm-password" ".*\nauth substack login[^\n]*\n.*") (pamMatches "gdm-password" ".*\naccount include login[^\n]*\n.*") (pamMatches "gdm-password" ".*pam_faillock.*")] [true true false];
    # sshd carries the same lines, and its auth stack has no pam_unix: a password is never
    # accepted over SSH, a key logon does not run the auth stack, and so the lock cannot
    # shut the operator out of SSH (sshStaysKeyOnlyWithTheOperatorKeys above).
    sshdAuthStackTakesNoPassword =
      assay.eq [(pamMatches "sshd" ".*\nauth required [^\n]*pam_faillock\\.so preauth [^\n]*\n.*") (pamMatches "sshd" ".*\nauth [^\n]*pam_unix\\.so.*")] [true false];
    # passwd, chpasswd, sudo: pam_pwquality directly AHEAD of the `sufficient` pam_unix, which
    # stores the password that was checked.
    passwordStacksCheckQualityBeforePamUnixStores =
      assay.eq (map (s: pamMatches s ".*\npassword requisite [^\n]*pam_pwquality\\.so[^\n]*\npassword sufficient [^\n]*pam_unix\\.so [^\n]*use_authtok[^\n]*\n.*") ["passwd" "chpasswd" "sudo"]) [true true true];
    # ... and never behind it, which is where the line sat when it enforced nothing.
    noQualityLineBehindPamUnix =
      assay.eq (map (s: pamMatches s ".*pam_unix\\.so[^\n]*\npassword [^\n]*pam_pwquality.*") ["passwd" "chpasswd" "sudo"]) [false false false];
    noFipsOnTheKernelCommandLine = assay.eq (builtins.elem "fips=1" host.boot.kernelParams) false; # V-268168
    timeServersAreNotPinned = assay.eq (builtins.any (s: builtins.match ".*navy\\.mil" s != null) host.networking.timeServers) false; # V-268149
  }
