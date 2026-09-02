# Custom NixOS installer ISO configuration
# Build: nix build .#installer-iso
# Flash: sudo dd if=result/iso/*.iso of=/dev/sdX bs=4M status=progress
{
  pkgs,
  lib,
  modulesPath,
  ...
}: {
  imports = [
    "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
  ];

  # Make the ISO bootable on both BIOS and UEFI systems
  isoImage = {
    makeEfiBootable = true;
    makeUsbBootable = true;
  };

  # Custom ISO name
  image.baseName = lib.mkForce "nixos-industrial-installer";

  # Enable SSH for remote installation
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "yes";
      PasswordAuthentication = true;
    };
  };

  # Set a default root password for the live environment (change after install!)
  users.users.root.initialPassword = "nixos";

  # Auto-login to console for convenience
  services.getty.autologinUser = lib.mkForce "root";

  # Packages available in the live environment
  environment.systemPackages = with pkgs; [
    # Essential tools
    git
    vim
    htop
    tmux

    # Disk utilities
    parted
    gptfdisk
    cryptsetup
    btrfs-progs
    dosfstools

    # Network utilities
    curl
    wget
    rsync
  ];

  # Pre-clone the dotfiles repository
  system.activationScripts.cloneDotfiles = ''
    if [ ! -d /root/.dotfiles ]; then
      echo "Cloning dotfiles repository..."
      ${pkgs.git}/bin/git clone https://github.com/Industrial/nixos-dotfiles.git /root/.dotfiles || true
    fi
  '';

  # Create the install script
  environment.etc."install-nixos".source = ./install-nixos.sh;

  # Add install-nixos to PATH
  environment.shellInit = ''
    export PATH="/etc:$PATH"
    alias install-nixos="bash /etc/install-nixos"

    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║         NixOS Industrial Fleet Installer                       ║"
    echo "╠════════════════════════════════════════════════════════════════╣"
    echo "║  Usage: install-nixos <hostname>                               ║"
    echo "║                                                                ║"
    echo "║  Available hosts: drakkar, huginn, mimir, muninn               ║"
    echo "║                                                                ║"
    echo "║  Example: install-nixos huginn                                 ║"
    echo "║                                                                ║"
    echo "║  The installer will:                                           ║"
    echo "║    1. Partition disk with disko                                ║"
    echo "║    2. Prompt for LUKS encryption password                      ║"
    echo "║    3. Install NixOS with your configuration                    ║"
    echo "║    4. Reboot into your new system                              ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
  '';

  # Network configuration for installation
  networking.hostName = "nixos-installer";

  # Nix configuration
  nix = {
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  system.stateVersion = "24.11";
}
