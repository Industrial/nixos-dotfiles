# Colocated suite: sshd hardening and crypto, on the evaluated configuration (ADR-0007).
let
  assay = import ./../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  config = nixos.eval {modules = [./default.nix];};
  s = config.services.openssh.settings;

  matching = pat: builtins.filter (a: builtins.match pat a != null);
in
  assay.suite "ssh" {
    enabled = assay.eq config.services.openssh.enable true;
    keyOnly = assay.eq [s.PasswordAuthentication s.KbdInteractiveAuthentication s.PubkeyAuthentication] [false false true];
    noRootLogin = assay.eq s.PermitRootLogin "no";
    verboseLogging = assay.eq s.LogLevel "VERBOSE";
    shortGrace = assay.eq s.LoginGraceTime 30;
    shedsFloods = assay.eq s.MaxStartups "10:30:60";
    sshguardOn = assay.eq config.services.sshguard.enable true;

    # Crypto comes from nixpkgs' defaults. These pin the property, not the list.
    kexIsPinned = assay.eq (s.KexAlgorithms != null && s.KexAlgorithms != []) true;
    kexHasPostQuantumHybrid =
      assay.eq ((matching "(mlkem768x25519|sntrup761x25519).*" s.KexAlgorithms) != []) true;
    kexNoNistOrSha1 = assay.eq (matching ".*(nistp|sha1|group1-|group14-).*" s.KexAlgorithms) [];
    noCbcCiphers = assay.eq (matching ".*-cbc.*|3des.*|arcfour.*" s.Ciphers) [];
    noWeakMacs = assay.eq (matching ".*(md5|sha1|-96).*" s.Macs) [];
  }
