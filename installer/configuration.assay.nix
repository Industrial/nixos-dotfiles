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
#
# The installer is evaluated exactly as the flake evaluates it: the root flake's outputs are
# called with the inputs resolved from flake.lock, and the claims read
# nixosConfigurations.installer. (common/assay/nixos.nix's own base module pins a stateVersion
# that conflicts with this file's, which is one more reason to use the flake's own system.)
let
  assay = import ./../common/assay/default.nix;
  nixos = import ./../common/assay/nixos.nix;
  lib = nixos.lib;

  flake = import ./../flake.nix;
  outputs = flake.outputs (nixos.flakeInputs // {self = outputs;});
  installer = outputs.nixosConfigurations.installer;
  cfg = installer.config;

  hosts = (import ./../common/fleet.nix).names;
in
  assay.suite "installer-configuration" {
    # --- containment: the point of this suite ---

    # The installer-iso package is this configuration's ISO, under the fleet's name.
    onlyReachableFromInstallerIso =
      assay.eq outputs.packages.x86_64-linux.installer-iso.name cfg.system.build.isoImage.name;
    # The ISO option tree only exists in a system that imports the installation-CD modules,
    # which is what this file does. No host has it, so no host reaches this file.
    noHostImportsTheInstaller =
      assay.eq (map (h: outputs.nixosConfigurations.${h}.options ? isoImage) hosts) (map (_: false) hosts);
    # Control for the claim above: the probe does see the installer's own ISO options.
    installerHasTheIsoOptions = assay.eq (installer.options ? isoImage) true;

    # --- the ISO is an installer, not a system ---
    buildsOnMinimalInstallationCd = assay.eq cfg.isoImage.edition "minimal";
    bootsBiosAndUefi = assay.eq [cfg.isoImage.makeEfiBootable cfg.isoImage.makeUsbBootable] [true true];
    isNamedForTheFleet = assay.eq cfg.image.baseName "nixos-industrial-installer";
    isoFileCarriesTheName = assay.eq cfg.system.build.isoImage.name "nixos-industrial-installer.iso";

    # --- deliberate, documented weaknesses ---
    # Asserted so they are a conscious property of this file rather than an accident, and so a
    # reviewer grepping for them finds this explanation attached.
    allowsRootSshForRemoteInstall =
      assay.eq [cfg.services.openssh.enable cfg.services.openssh.settings.PermitRootLogin] [true "yes"];
    allowsSshPasswords = assay.eq cfg.services.openssh.settings.PasswordAuthentication true;
    usesKnownLivePassword = assay.eq cfg.users.users.root.initialPassword "nixos";
    # Forced null, so the live password is the only one in play.
    noOtherRootPassword =
      assay.eq [cfg.users.users.root.hashedPassword cfg.users.users.root.hashedPasswordFile cfg.users.users.root.password] [null null null];
    autologinsToRootConsole = assay.eq cfg.services.getty.autologinUser "root";

    # --- the tools an install actually needs ---
    # cryptsetup is load-bearing: every host's disko layout is LUKS (V-268144), so an ISO
    # without it cannot complete an install.
    shipsCryptsetup = assay.eq (nixos.hasPackage cfg "cryptsetup") true;
    shipsBtrfsProgs = assay.eq (nixos.hasPackage cfg "btrfs-progs") true;
    shipsDiskPartitioners = assay.eq [(nixos.hasPackage cfg "parted") (nixos.hasPackage cfg "gptfdisk")] [true true];

    enablesFlakes =
      assay.eq (lib.hasInfix "experimental-features = nix-command flakes" cfg.nix.extraOptions) true;
    # The install script ships in /etc, and the shell init puts it on PATH.
    providesInstallScript = assay.eq cfg.environment.etc."install-nixos".source ./install-nixos.sh;
    installScriptIsOnPath =
      assay.eq (lib.hasInfix ''alias install-nixos="bash /etc/install-nixos"'' cfg.environment.shellInit) true;
  }
