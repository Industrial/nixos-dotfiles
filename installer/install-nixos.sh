#!/usr/bin/env bash
# NixOS Industrial Fleet Installer
# Usage: install-nixos <hostname>

set -euo pipefail

HOSTNAME="${1:-}"
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
    echo "Usage: install-nixos <hostname>"
    echo ""
    echo "Available hosts:"
    for host in "${VALID_HOSTS[@]}"; do
        echo "  - $host"
    done
    echo ""
    echo "Example: install-nixos huginn"
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

# Confirm installation
log_warn "This will WIPE ALL DATA on the target disk!"
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

# Run the host's own destroyFormatMount script rather than `disko --mode ... hosts/X/disko.nix`.
# Two reasons:
#   - It uses the disko version pinned in this repo's flake.lock, not whatever
#     github:nix-community/disko/latest resolves to today. The layout and the tool that applies
#     it then come from the same commit.
#   - It evaluates the real host configuration, so a layout that depends on anything outside
#     disko.nix is applied exactly as the installed system will expect it.
nix --experimental-features "nix-command flakes" run \
    ".#nixosConfigurations.$HOSTNAME.config.system.build.destroyFormatMount" -- \
    --yes-wipe-all-disks

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
