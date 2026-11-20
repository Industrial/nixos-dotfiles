# STIG fleet-baseline profile: the controls safe on EVERY host, including the interactive
# ones (ADR-0007).
#
# ADR-0004 took the whole base-safe profile off drakkar, huginn and muninn because of the
# audit set's cost. Its own "Negative" section names what that also dropped: firewall,
# AppArmor, no-root SSH, kernel sysctls, require-sigs. Those cost an interactive user
# nothing. This profile brings exactly those back, and leaves out everything that has a cost
# on a workstation (each exclusion and the reason for it is in ADR-0007):
#   - the audit set (V-268080 and the syscall/watch rules): the cost ADR-0004 exists for
#   - V-268089/V-268157 (Ciphers/MACs): narrower and weaker than the nixpkgs defaults
#   - V-268130 (ENCRYPT_METHOD SHA512): a downgrade from the yescrypt default
#   - V-268085 (maxlogins 10): deploy-rs and remote builds open parallel SSH sessions
#   - V-268181 (UMASK 077): breaks the shared group directories /data and /games
#   - pwquality, FAIL_DELAY, vlock, timesyncd polling: interactive cost, no security value
#     off an accredited host
#
# Every control here is also in base-safe.nix. On mimir, which imports both, the module
# system deduplicates the imports by path, and base-safe's `implemented` and `profile`
# (normal priority) replace this file's mkDefault ones. So mimir's report is unchanged. The
# colocated suite asserts the subset property, which is what makes that safe.
#
# Wiring: list this file in features/catalog.nix, which declares
# features.security.stig.profiles.fleet-baseline.enable, and set that to true in
# profiles/base.nix. Both files belong to another workstream, so this is listed as a
# follow-up in the PR rather than made here.
{lib, ...}: let
  controlModules = [
    ../controls/V-268078.nix # built-in firewall enabled
    ../controls/V-268131.nix # telnet absent (CAT I, assertion)
    ../controls/V-268141.nix # IPv4 TCP syncookies
    ../controls/V-268151.nix # time synchronization enabled
    ../controls/V-268173.nix # AppArmor enabled
    ../controls/V-268154.nix # require-sigs (CAT I)
    ../controls/V-268156.nix # sudo requires a password
    ../controls/V-268160.nix # kernel.kptr_restrict = 1
    ../controls/V-268161.nix # kernel.randomize_va_space = 2

    # SSH: everything in base-safe's group 3 except the cipher/MAC pins.
    ../controls/V-268088.nix # sshd LogLevel VERBOSE
    ../controls/V-268137.nix # no direct root login over SSH
    ../controls/V-268142.nix # ClientAliveInterval 600
    ../controls/V-268143.nix # ClientAliveCountMax 1
    ../controls/V-268159.nix # encrypted transport enabled (CAT I)
    ../controls/V-268176.nix # SSH authenticates through PAM (CAT I)
  ];

  idOf = path: builtins.head (builtins.match "(V-[0-9]+)\\.nix" (builtins.baseNameOf (toString path)));
in {
  imports = [../default.nix] ++ controlModules;

  security.stig = {
    enable = true;
    profile = lib.mkDefault "fleet-baseline";
    implemented = lib.mkDefault (map idOf controlModules);
  };
}
