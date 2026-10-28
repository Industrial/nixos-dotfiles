# V-268088 (CAT II) — NixOS must monitor remote access methods.
#
# Fix text: services.openssh.logLevel = "VERBOSE";
#
# `services.openssh.logLevel` still resolves on current nixpkgs, but only through a
# mkRenamedOptionModule alias (sshd.nix line 207). The canonical option is
# `services.openssh.settings.LogLevel`, which is what is used here — a renamed option is a
# deprecation warning waiting to become an eval error.
#
# This control genuinely changes something: the fleet currently evaluates to LogLevel "INFO".
# VERBOSE additionally logs the key fingerprint used for each authentication, which is what
# makes "monitor remote access" meaningful. The cost is log volume only.
{...}: {
  services.openssh.settings.LogLevel = "VERBOSE";
}
