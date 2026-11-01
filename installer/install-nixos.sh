#!/usr/bin/env bash
# NixOS Industrial Fleet Installer
# Usage: install-nixos <hostname> [--wipe]

set -euo pipefail

HOSTNAME="${1:-}"
WIPE="${2:-}"
DOTFILES_DIR="/root/.dotfiles"
VALID_HOSTS=("drakkar" "huginn" "mimir" "muninn")

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

print_usage() {
    echo "Usage: install-nixos <hostname> [--wipe]"
    echo ""
    echo "Available hosts:"
    for host in "${VALID_HOSTS[@]}"; do
        echo "  - $host"
    done
    echo ""
    echo "Example: install-nixos huginn"
    echo ""
    echo "By default the disk layout is applied non-destructively: partitions and"
    echo "filesystems that already exist are kept, and only what is missing is created."
    echo "This is what lets mimir be reinstalled without touching its /data RAID5 array."
    echo ""
    echo "  --wipe   Destroy every disk the host declares first, then recreate from"
    echo "           scratch. On mimir that includes all four data disks. There is no"
    echo "           second confirmation: only pass this if that is what you mean."
}

validate_hostname() {
    for host in "${VALID_HOSTS[@]}"; do
        if [[ "$host" == "$HOSTNAME" ]]; then
            return 0
        fi
    done
    return 1
}

# Check if hostname provided
if [[ -z "$HOSTNAME" ]]; then
    log_error "No hostname provided"
    print_usage
    exit 1
fi

# Validate hostname
if ! validate_hostname; then
    log_error "Invalid hostname: $HOSTNAME"
    print_usage
    exit 1
fi

log_info "Installing NixOS configuration: $HOSTNAME"

# Ensure dotfiles are present
if [[ ! -d "$DOTFILES_DIR" ]]; then
    log_info "Cloning dotfiles repository..."
    git clone https://github.com/Industrial/nixos-dotfiles.git "$DOTFILES_DIR"
fi

cd "$DOTFILES_DIR"

# Pull latest changes
log_info "Updating dotfiles..."
git pull --rebase || log_warn "Could not update dotfiles (offline?)"

# Show disk layout
log_info "Current disk layout:"
lsblk
echo ""

# Name every disk the host declares, so the confirmation below is about real devices rather
# than an abstract "the target disk". On mimir that list is five disks, four of them /data.
log_info "Disks declared by $HOSTNAME:"
DECLARED_DISKS=$(nix --experimental-features "nix-command flakes" eval --raw \
        ".#nixosConfigurations.$HOSTNAME.config.disko.devices.disk" \
    --apply 'ds: builtins.concatStringsSep "\n" (map (d: "  - " + d.device) (builtins.attrValues ds))')
echo "$DECLARED_DISKS"
echo ""

# Confirm installation
if [[ "$WIPE" == "--wipe" ]]; then
    log_warn "--wipe given: every disk listed above will be DESTROYED and recreated."
    log_warn "On mimir that destroys the /data RAID5 array (~55 TB). This is not recoverable."
else
    log_info "Applying the layout non-destructively: existing partitions and filesystems are"
    log_info "kept, and only what is missing gets created. Pass --wipe to start from scratch."
fi
log_warn "Host configuration: $HOSTNAME"
echo ""
read -p "Are you sure you want to continue? (yes/no): " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
    log_info "Installation cancelled"
    exit 0
fi

# Run disko to partition and format
log_info "Running disko to partition and format disk..."
log_info "You will be prompted for the LUKS encryption password"
echo ""

# Run the host's own disko script rather than `disko --mode ... hosts/X/disko.nix`.
# Two reasons:
#   - It uses the disko version pinned in this repo's flake.lock, not whatever
#     github:nix-community/disko/latest resolves to today. The layout and the tool that applies
#     it then come from the same commit.
#   - It evaluates the real host configuration, so a layout that depends on anything outside
#     disko.nix is applied exactly as the installed system will expect it.
#
# formatMount vs destroyFormatMount is the whole difference between "reinstall the OS" and
# "lose /data". The destroy phase is what runs `wipefs --all -f` on every partition and
# `dd if=/dev/zero bs=440 count=1` over the MBR; the format phase on its own is guarded —
# `sgdisk --clear` only when the disk carries no signature, partition creation falls back to
# relabelling when the partition exists, and mkfs only when `blkid` reports no TYPE=. So the
# default path recreates what is missing and leaves what is already there alone.
if [[ "$WIPE" == "--wipe" ]]; then
    log_warn "Destroying and recreating every declared disk (--wipe)..."
    nix --experimental-features "nix-command flakes" run \
        ".#nixosConfigurations.$HOSTNAME.config.system.build.destroyFormatMount" -- \
        --yes-wipe-all-disks
else
    nix --experimental-features "nix-command flakes" run \
        ".#nixosConfigurations.$HOSTNAME.config.system.build.formatMount"
fi

log_success "Disk partitioned and mounted"

# Generate hardware configuration (optional, we have our own)
# nixos-generate-config --root /mnt

# Copy dotfiles to the new system
log_info "Setting up dotfiles in new system..."
mkdir -p /mnt/home/tom
cp -r "$DOTFILES_DIR" /mnt/home/tom/.dotfiles

# Install NixOS
log_info "Installing NixOS..."
nixos-install --flake ".#$HOSTNAME" --no-root-passwd

# The copy above ran as root in the live environment, so every file landed root-owned. Fix it
# now that the installed system knows who tom is.
log_info "Giving tom ownership of the copied dotfiles..."
nixos-enter --root /mnt -c 'chown -R tom /home/tom' || \
    log_warn "Could not chown /home/tom — run 'chown -R tom /home/tom' after first boot"

log_success "Installation complete!"
echo ""
log_warn "SET A PASSWORD BEFORE YOU REBOOT."
log_warn "No host declares a password, so both accounts are created locked, and no host"
log_warn "enables console autologin. Rebooting without doing this leaves a login prompt"
log_warn "nothing gets you past at the machine itself."
echo ""
log_info "Post-installation steps:"
echo "  1. Set root password: nixos-enter --root /mnt -c 'passwd'"
echo "  2. Set user password: nixos-enter --root /mnt -c 'passwd tom'"
echo "  3. Reboot: reboot"
echo ""
log_info "If you do reboot too early, it is recoverable but not from the console: SSH in as"
log_info "tom from another fleet host (the key is already authorized, and tom has NOPASSWD"
log_info "sudo) and run 'sudo passwd tom'. Otherwise boot this USB stick again and use"
log_info "nixos-enter as above."
echo ""

read -p "Reboot now? (yes/no): " REBOOT
if [[ "$REBOOT" == "yes" ]]; then
    log_info "Rebooting..."
    reboot
fi
