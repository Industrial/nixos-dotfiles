# STIG test-host profile — the whole benchmark accounted for on one real machine.
#
# Enabled by hosts/muninn/configuration.nix, and by that host only (ADR-0008). muninn is the
# fleet's STIG test host: every one of the 103 controls is either configured here, covered by
# external evidence (profiles/external-evidence.nix), or excluded below with a written reason.
# Nothing is left "Not Implemented".
#
# It differs from profiles/full.nix in one way that matters. `full` configures everything and
# is for VM targets, where a control that locks the machine out is a test result. This profile
# runs on a laptop with an operator, a deployer and one network uplink, so the controls that
# would cut any of those off are excluded, and each exclusion says what would have to be true
# for the control to be applied.
#
# Composition: base-safe's 68 controls by import, never by a second copy of its list, plus the
# 15 below. `implemented` is a list, so the two profiles' contributions concatenate.
{lib, ...}: let
  baseSafeProfile = ./base-safe.nix;

  # Controls from the `full` set that this host carries on top of base-safe.
  testHostModules = [
    # Consent banners — ../lib/dow-banner.nix holds the text once for all three.
    ../controls/V-268082.nix # console / CLI
    ../controls/V-268083.nix # SSH
    ../controls/V-268084.nix # graphical greeter

    # Logon controls. V-268081 (three-strike lockout) is excluded below, not carried.
    ../controls/V-268086.nix # 10-minute idle lock
    ../controls/V-268172.nix # no console autologin (CAT I, assertion)
    ../controls/V-268174.nix # disable accounts after 35 days idle

    # Audit notification.
    ../controls/V-268101.nix # notify at 75% volume
    ../controls/V-268102.nix # notify at 90% volume

    # Password policy beyond complexity. V-268170 (pam_pwquality in the PAM password stack)
    # is excluded below, not carried.
    ../controls/V-268132.nix # PASS_MIN_DAYS 1
    ../controls/V-268133.nix # PASS_MAX_DAYS 180
    ../controls/V-268134.nix # minlen 15

    # Accounts and privilege.
    ../controls/V-268135.nix # unique interactive UIDs (assertion)
    ../controls/V-268136.nix # PKCS#11 token support (package only)
    ../controls/V-268152.nix # nix daemon limited to root + wheel
    ../controls/V-268155.nix # no sudo credential cache
  ];

  idOf = path: builtins.head (builtins.match "(V-[0-9]+)\\.nix" (builtins.baseNameOf (toString path)));
in {
  imports = [baseSafeProfile] ++ testHostModules;

  security.stig = {
    # mkForce because base-safe, which this profile imports, labels itself "base-safe". The
    # report reads this label to say which baseline a host carries.
    profile = lib.mkForce "test-host";

    # base-safe's 68 plus these 15. Derived from the import list, never hand-listed.
    implemented = map idOf testHostModules;

    # `requiresReboot` and `deferredVerification` come from base-safe unchanged. None of the 15
    # controls above is a kernel parameter or runtime-only state, and an excluded control has
    # nothing to defer.

    # Not applied on this host, each with the reason. The first three are the benchmark's
    # procedural controls and are excluded wherever the benchmark is carried. Fourteen are
    # decisions about this machine, and the ones that wait on the owner say so. The last two
    # are controls whose module renders a PAM line that does not enforce the requirement: a
    # control that is present and not in effect must not be reported as compliant, and an
    # untested PAM line does not go into the login stacks of a real machine.
    exclude =
      import ../lib/procedural-exclusions.nix
      // {
        # --- radios ---
        "V-268146" = "Not applied (CAT I). The published fix is networking.wireless.enable = false, which removes wpa_supplicant. On this host that option evaluates true because NetworkManager uses wpa_supplicant as its WiFi backend, so the fix turns WiFi off. WiFi is this laptop's only uplink: with it off the host drops off the network and out of reach of its deployer.";
        "V-268147" = "Not applied, pending the owner's ruling. The fix is hardware.bluetooth.enable = false. Bluetooth is enabled on this host deliberately (hosts/muninn/hardware.nix and features/nixos/bluetooth) for the operator's peripherals, and applying the control removes them.";

        # --- cryptography and time ---
        "V-268168" = "Not applied (CAT I). NixOS ships no FIPS-validated cryptographic module, so fips=1 on the kernel command line would assert a validation that does not exist, and the requirement would still not be met. In FIPS mode the kernel also rejects non-approved algorithms, which risks a host that cannot unlock its LUKS root (V-268144). To be revisited with VM evidence that a LUKS-rooted NixOS boots with fips=1.";
        "V-268149" = "Not applied. The fix pins tick.usnogps.navy.mil and tock.usnogps.navy.mil as the only time servers; they are DoD servers and this host is not on a DoD network, so the change would replace working time servers with unreachable ones. Time synchronisation itself is on (V-268151) with the poll interval the benchmark requires (V-268150).";

        # --- audit off-load ---
        "V-268108" = "Not applied. The fleet has no remote log collector, so there is no endpoint to off-load audit records to (security.stig.remoteLogging.url has no default by design). Records stay on this host, on its LUKS-encrypted disk, under the storage thresholds and actions of V-268103, V-268104, V-268105 and V-268106.";
        "V-268109" = "Not applied. There is no remote log server to authenticate, because audit records are not off-loaded (see V-268108). Becomes applicable together with V-268108 once a collector exists.";

        # --- PKI, directory and multifactor ---
        "V-268124" = "Not applied. The control needs a PKI trust anchor and an SSSD configuration that consumes it (security.stig.pkiCaBundle, security.stig.sssdConfig). The fleet has no directory service and no DoD PKI; the single operator account is local and no certificate authentication is in use.";
        "V-268178" = "Not applied. The requirement expires authenticators cached by SSSD after one day. This host runs no SSSD and has no network identity provider, so there are no cached authenticators; the single operator account is local.";
        "V-268177" = "Not applied. The fix is security.pam.p11.enable = true, which authenticates against a certificate on a PKCS#11 token. No such token is issued to the operator and the fleet has no PKI to issue one (V-268124), so enabling pam_p11 would add a module to the login stacks with nothing to verify.";
        "V-268179" = "Not applied. The control caches certificate revocation data for PKI authentication through pam_p11. With no PKI authentication on this host (V-268124, V-268177) there are no certificates to validate and no revocation data to cache.";

        # --- modules that render but do not enforce ---
        "V-268081" = "Not applied until the control module is reworked and has a VM test. The module adds one pam_faillock.so line to the login and sshd auth stacks with none of the preauth, authfail or authsucc arguments. pam_faillock then only checks the tally and never records a failed attempt, so no account is ever locked. Carrying it would report a three-attempt lockout that does not exist.";
        "V-268170" = "Not applied until the control module is reworked and has a VM test. The module adds pam_pwquality.so to the passwd, chpasswd and sudo password stacks after a 'sufficient' pam_unix.so, so a successful pam_unix ends the stack and pam_pwquality is never reached. The pwquality.conf settings of V-268126, V-268127, V-268128, V-268129, V-268134, V-268145 and V-268169 are written to /etc/security/pwquality.conf on this host, but PAM does not enforce them until this control returns.";

        # --- integrity, devices, accounts, network ---
        "V-268153" = "Not applied. The control mails AIDE integrity reports to designated personnel, and this host has no mail transport and no address to deliver to (security.stig.aideMailTo has no default by design). Unauthorised change to the system closure is prevented by the read-only Nix store with signature checking (V-268154). No scheduled integrity check runs on this host: features/nix/vverify, the fleet's store verifier, is not enabled here.";
        "V-268139" = "Not applied, waiting for the owner. usbguard blocks every USB device that is not in its policy, and the policy has to be generated on the device with the operator's real peripherals attached (usbguard generate-policy). That is a root action at the laptop; until services.usbguard.rules holds that policy, enabling the service would block those peripherals.";
        "V-268138" = "Not applied, waiting on secret management (#340, #341). users.mutableUsers = false makes every account's password come from the configuration, and the operator's password hash is not declared in Nix yet. Applying it now would replace the operator's password with the placeholder initial hash in features/nixos/users.";
        "V-268158" = "Not applied. The published rule refuses SSH traffic above 1 MB/s from a single source address. The fleet moves Nix store paths over SSH (nix copy on deploy, remote builds; this host runs the remote-builder server), so the limit would refuse the host's own deploy and build traffic.";
      };
  };
}
