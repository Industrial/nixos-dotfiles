# OpenSSH server and sshguard, fleet-wide (via features/fleet/remote-access.nix).
#
# Crypto (ADR-0006): the nixpkgs 26.11 defaults are already the modern set: ML-KEM/sntrup
# hybrid and curve25519 key exchange, chacha20-poly1305 and AES-GCM/CTR ciphers, and
# encrypt-then-MAC SHA-2 MACs. Pinning our own copy would only let it go stale, so this
# module does not, and default.assay.nix asserts on the evaluated lists instead. That way an
# upstream or local regression to CBC, SHA-1 or NIST-curve exchange fails CI.
#
# On mimir the STIG controls V-268089/V-268157 narrow Ciphers/MACs to the STIG's CTR/HMAC
# list. That is a conformance choice for the one assessed host (ADR-0004), not a weakness.
#
# Brute force: sshguard, not fail2ban. sshguard is already wired and blocks through the
# firewall backend NixOS picks. fail2ban would watch the same log a second time and add
# nothing for a key-only server.
{lib, ...}: {
  services = {
    openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        PubkeyAuthentication = true;
        PermitRootLogin = "no";
        KbdInteractiveAuthentication = false;
        # Low by design; fleet clients use IdentitiesOnly (see features/fleet/operator-ssh.nix).
        MaxAuthTries = 3;
        X11Forwarding = false;
        # Logs the fingerprint of the key that authenticated, which is what an incident
        # review needs. Same value the STIG sets on mimir (V-268088).
        LogLevel = lib.mkDefault "VERBOSE";
        # Unauthenticated connections get 30s instead of 120s, and get shed early under a
        # flood. Agent forwarding and TCP forwarding stay on: pam sshAgentAuth and remote
        # development use them.
        LoginGraceTime = lib.mkDefault 30;
        MaxStartups = lib.mkDefault "10:30:60";
      };
    };

    sshguard = {
      enable = true;
      whitelist = [
        "127.0.0.1"
        "::1"
        # Tailscale CGNAT — fleet peers authenticate over the mesh.
        "100.64.0.0/10"
      ];
    };
  };
}
