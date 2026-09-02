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

nix --experimental-features "nix-command flakes" run github:nix-community/disko/latest -- \
    --mode destroy,format,mount \
    "./hosts/$HOSTNAME/disko.nix" \
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

log_success "Installation complete!"
echo ""
log_info "Post-installation steps:"
echo "  1. Set root password: nixos-enter --root /mnt -c 'passwd'"
echo "  2. Set user password: nixos-enter --root /mnt -c 'passwd tom'"
echo "  3. Reboot: reboot"
echo ""
log_info "Or just reboot and set passwords on first login"
echo ""

read -p "Reboot now? (yes/no): " REBOOT
if [[ "$REBOOT" == "yes" ]]; then
    log_info "Rebooting..."
    reboot
fi
