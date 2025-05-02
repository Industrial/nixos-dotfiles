# Mimir Installation Guide

This guide covers both manual installation using a live ISO and remote installation using nixos-anywhere.

## Prerequisites

- SSH key pair for remote access
- Network access to the target machine
- Root access to the target machine

## Option 1: Manual Installation

1. Boot the target machine with a NixOS live ISO
2. Enable SSH and set a root password:
   ```bash
   systemctl start sshd
   passwd
   ```
3. From your workstation, SSH into the live system:
   ```bash
   ssh root@<target-ip>
   ```
4. Clone this repository:
   ```bash
   git clone <your-repo-url>
   cd <repo-name>
   ```
5. Apply the disk layout:
   ```bash
   nix run github:nix-community/disko -- --mode disko .#mimir
   ```
6. Install NixOS:
   ```bash
   nixos-install --flake .#mimir
   ```
7. Reboot:
   ```bash
   reboot
   ```

## Troubleshooting

### If the installation fails:

1. Check the logs:
   ```bash
   journalctl -xe
   ```
2. Verify disk layout:
   ```bash
   lsblk
   ```
3. Check network connectivity:
   ```bash
   ip a
   ping 8.8.8.8
   ```

### If you need to start over:

1. Boot into the live ISO
2. Wipe the disks:
   ```bash
   wipefs -a /dev/nvme0n1
   wipefs -a /dev/sda
   wipefs -a /dev/sdb
   wipefs -a /dev/sdc
   wipefs -a /dev/sdd
   ```
3. Start the installation process again

## Security Notes

- Change the default root password immediately after installation
- Disable root login and password authentication after setup
- Use SSH keys for authentication
- Keep your system updated regularly 