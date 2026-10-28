# STIG full profile — the complete Anduril NixOS STIG baseline.
#
# ⚠ THIS PROFILE MUST NOT BE IMPORTED BY A WORKSTATION. It is for VM test targets, and
# `tests/vm/full.assay.nix` asserts no hosts/*/configuration.nix imports it.
#
# What makes it unsuitable for a daily driver, in rough order of how fast you would notice:
#
#   V-268138  users.mutableUsers = false — `passwd` stops working; every password must be
#             declared in Nix before activation or the account is unusable
#   V-268139  usbguard blocks unauthorised USB, including the keyboard and the YubiKey
#   V-268081  three failed logons lock the account with NO automatic unlock
#   V-268086  forced screen lock after 10 minutes idle
#   V-268147  Bluetooth off — audio and peripherals gone
#   V-268158  SSH traffic above 1 MB/s per source is REFUSED, breaking scp and rsync
#   V-268155  every sudo prompts; no credential cache at all
#   V-268149  time servers pinned to DoD hosts unreachable from a home network
#   V-268168  fips=1 — the highest-risk control in the benchmark; see its module
#   V-268174  accounts disabled after 35 days idle, which is how a drawer laptop locks itself
#   V-268082/083/084  seven paragraphs of consent banner before every login, SSH included
#
# Several controls additionally need site input and will REFUSE TO BUILD until it is
# supplied — deliberately, because a plausible default would produce a host that believes it
# is shipping audit records or validating certificates when it is not:
#
#   security.stig.remoteLogging.{url,trustedCertificateFile,…}  V-268108, V-268109
#   security.stig.pkiCaBundle, security.stig.sssdConfig          V-268124, V-268178
#   security.stig.aideMailTo                                     V-268153
#   services.usbguard.rules                                      V-268139
{lib, ...}: let
  baseSafeProfile = ./base-safe.nix;

  # The controls base-safe does not carry. Together with base-safe's 68 and the two handled
  # below, this covers all 103.
  fullOnlyModules = [
    # Consent banners — ../lib/dow-banner.nix holds the text once for all three.
    ../controls/V-268082.nix # console / CLI
    ../controls/V-268083.nix # SSH
    ../controls/V-268084.nix # graphical greeter

    # Logon controls.
    ../controls/V-268081.nix # three-strike lockout, no auto-unlock
    ../controls/V-268086.nix # 10-minute idle lock
    ../controls/V-268172.nix # no console autologin (CAT I, assertion)
    ../controls/V-268174.nix # disable accounts after 35 days idle

    # Audit notification and off-load.
    ../controls/V-268101.nix # notify at 75% volume
    ../controls/V-268102.nix # notify at 90% volume
    ../controls/V-268108.nix # off-load audit records (site input)
    ../controls/V-268109.nix # authenticate the log server (site input)

    # Password policy beyond complexity.
    ../controls/V-268132.nix # PASS_MIN_DAYS 1
    ../controls/V-268133.nix # PASS_MAX_DAYS 180
    ../controls/V-268134.nix # minlen 15
    ../controls/V-268170.nix # pam_pwquality in the password stack
    ../controls/V-268178.nix # cached authenticators expire after a day (site input)

    # Accounts, devices and radios.
    ../controls/V-268135.nix # unique interactive UIDs (assertion)
    ../controls/V-268138.nix # users.mutableUsers = false
    ../controls/V-268139.nix # usbguard (needs a policy)
    ../controls/V-268146.nix # wireless disabled (CAT I)
    ../controls/V-268147.nix # Bluetooth disabled
    ../controls/V-268152.nix # nix daemon limited to root + wheel
    ../controls/V-268155.nix # no sudo credential cache

    # PKI and multifactor.
    ../controls/V-268124.nix # trust anchor + SSSD (site input)
    ../controls/V-268136.nix # PKCS#11 token support
    ../controls/V-268177.nix # second factor from a separate device
    ../controls/V-268179.nix # locally cached revocation data

    # Network, time, integrity, crypto.
    ../controls/V-268149.nix # USNO time servers (unreachable off a DoD network)
    ../controls/V-268153.nix # AIDE baseline integrity (site input)
    ../controls/V-268158.nix # hashlimit rate limiting (refuses SSH over 1 MB/s)
    ../controls/V-268168.nix # fips=1 (CAT I, highest risk)
  ];

  idOf = path: builtins.head (builtins.match "(V-[0-9]+)\\.nix" (builtins.baseNameOf (toString path)));
in {
  imports = [baseSafeProfile] ++ fullOnlyModules;

  security.stig = {
    # mkForce because base-safe, which this profile imports, labels itself "base-safe". Both
    # definitions are live and `profile` is a single value, so the narrower one has to win
    # explicitly — the report reads this label to say which baseline a host carries.
    profile = lib.mkForce "full";

    # base-safe's 68 plus these. `implemented` is a list, so the two profiles' contributions
    # concatenate and the report sees all 101 implemented controls. Derived from the import
    # list, never hand-listed.
    implemented = map idOf fullOnlyModules;

    # Three controls in the benchmark have no configuration to carry, and saying so explicitly
    # is the only honest way to reach 103.
    #
    # V-268079 was classified `n-a` in docs/security/stig-triage.md from the start but was
    # never declared anywhere, so it fell through every count. full.assay.nix's completeness
    # assertion is what caught it — 102 of 103 accounted for — which is the whole reason that
    # assertion compares against the manifest rather than trusting a tally.
    exclude = {
      # Policy, not configuration. The requirement is that emergency and temporary accounts
      # expire within 72 hours; this fleet creates none. There is no option to set, only a
      # commitment to re-assert this justification if such an account is ever added.
      "V-268079" = "No emergency or temporary accounts exist on any host in this fleet, so there is nothing to apply an expiry to. Must be re-asserted if one is ever created — an account with no expiry would then be an undetected finding.";

      # Procedural. The requirement is that private keys are protected by a passphrase, which
      # is a property of keys users generate, not of system configuration. The fix text is a
      # command to run (`ssh-keygen -n [passphrase]`) and it is also wrong: -n is not the
      # passphrase flag, -N is. Nothing here can assert what passphrase a user chose.
      "V-268125" = "Procedural: private-key passphrase protection is a property of user-generated keys, not of system configuration. The fix text is a command for an operator to run, and names the wrong ssh-keygen flag (-n rather than -N). No configuration can assert it.";

      # Procedural. "Run a supported release of the operating system" is satisfied by this
      # repo's nixpkgs pin and its update policy, not by an option.
      "V-268180" = "Procedural: satisfied by the flake's nixpkgs pin and update policy rather than by any NixOS option.";
    };

    # fips=1 is a kernel parameter, so like V-268092/V-268093 it cannot take effect until the
    # host reboots. Registering it keeps the report from claiming compliance on a target that
    # has only switched.
    requiresReboot = {
      "V-268168" = "sets fips=1 on the kernel command line; the running kernel keeps the parameters it booted with until the host reboots.";
    };
  };
}
