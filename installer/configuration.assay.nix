# Colocated suite for installer/configuration.nix.
#
# This ISO is deliberately wide open — root SSH login, password authentication, a known root
# password of "nixos", console autologin. That is correct for a live installer you boot from a
# USB stick to partition a disk, and catastrophic anywhere else.
#
# So the suite's most important job is not checking that those settings exist; it is pinning
# the fact that this file is reachable ONLY from the installer-iso output, and never from a
# host configuration. The Anduril NixOS STIG controls V-268137 (no root SSH login), V-268138
# (no direct root login) and V-268172 (no unattended logon) are all deliberately violated
# here, and that is only defensible because the blast radius is one ISO.
let
  assay = import ./../common/assay/default.nix;
  src = builtins.readFile ./configuration.nix;
  flakeSrc = builtins.readFile ./../flake.nix;
  baseSrc = builtins.readFile ./../profiles/base.nix;
  has = pat: s: builtins.match pat s != null;
in
  assay.suite "installer-configuration" {
    # --- containment: the point of this suite ---

    # Only the installer-iso output may reach this file. If a host ever imported it, the
    # deliberate weaknesses below would land on a real machine.
    onlyReachableFromInstallerIso = assay.eq (has ".*nixosConfigurations\\.installer\\.config\\.system\\.build\\.isoImage.*" flakeSrc) true;
    notImportedByBaseProfile = assay.eq (has ".*installer.*" baseSrc) false;

    # --- the ISO is an installer, not a system ---
    buildsOnMinimalInstallationCd = assay.eq (has ".*installer/cd-dvd/installation-cd-minimal\\.nix.*" src) true;
    bootsBiosAndUefi = assay.eq (has ".*makeEfiBootable = true;.*" src && has ".*makeUsbBootable = true;.*" src) true;
    isNamedForTheFleet = assay.eq (has ".*nixos-industrial-installer.*" src) true;

    # --- deliberate, documented weaknesses ---
    # Asserted so they are a conscious property of this file rather than an accident, and so a
    # reviewer grepping for them finds this explanation attached.
    allowsRootSshForRemoteInstall = assay.eq (has ".*PermitRootLogin = \"yes\";.*" src) true;
    usesKnownLivePassword = assay.eq (has ".*initialPassword = \"nixos\";.*" src) true;
    autologinsToRootConsole = assay.eq (has ".*autologinUser = lib\\.mkForce \"root\";.*" src) true;

    # --- the tools an install actually needs ---
    # cryptsetup is load-bearing: every host's disko layout is LUKS (V-268144), so an ISO
    # without it cannot complete an install.
    shipsCryptsetup = assay.eq (has ".*cryptsetup.*" src) true;
    shipsBtrfsProgs = assay.eq (has ".*btrfs-progs.*" src) true;
    shipsDiskPartitioners = assay.eq (has ".*parted.*" src && has ".*gptfdisk.*" src) true;

    enablesFlakes = assay.eq (has ".*experimental-features = nix-command flakes.*" src) true;
    providesInstallScript = assay.eq (builtins.pathExists ./install-nixos.sh) true;
  }
