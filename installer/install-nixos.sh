#!/usr/bin/env bash
# NixOS Industrial Fleet Installer
# Usage: install-nixos <hostname> [--wipe] [--disk <name>=<device>]...

set -euo pipefail

HOSTNAME="${1:-}"
[[ $# -gt 0 ]] && shift
WIPE=""
DISK_OVERRIDES=() # "name=/dev/..." pairs, applied on top of the host's disko layout
while [[ $# -gt 0 ]]; do
    case "$1" in
        --wipe) WIPE="--wipe" ;;
        --disk)
            DISK_OVERRIDES+=("${2:-}")
            shift
            ;;
        --disk=*) DISK_OVERRIDES+=("${1#--disk=}") ;;
        *)
            echo "Unknown argument: $1" >&2
            exit 1
            ;;
    esac
    shift
done
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
    echo "Usage: install-nixos <hostname> [--wipe] [--disk <name>=<device>]..."
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
    echo ""
    echo "  --disk <name>=<device>"
    echo "           Point one declared disk at another device for this install only, e.g."
    echo "           --disk hdd-d=/dev/disk/by-id/ata-<model>_<serial>"
    echo "           For when /dev/sdX names have shifted (the USB stick takes a letter)."
    echo "           Repeatable. Prefer /dev/disk/by-id paths: they never shift."
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

# Every disko step below runs against this expression rather than the bare flake attribute, so
# --disk overrides apply to the layout without editing the repo. extendModules re-evaluates the
# real host configuration with the overrides on top; with none it is the host as-is. Device
# paths matter only while partitioning: the installed system mounts by partlabel and filesystem
# label, so nixos-install below keeps using the unmodified flake.
OVERRIDE_ATTRS=""
for override in "${DISK_OVERRIDES[@]}"; do
    name="${override%%=*}"
    device="${override#*=}"
    # Both halves are interpolated into a Nix expression: accept only plain names and /dev paths.
    if [[ "$override" != *=* || ! "$name" =~ ^[A-Za-z0-9_-]+$ || ! "$device" =~ ^/dev/[A-Za-z0-9._:/+-]+$ ]]; then
        log_error "Bad --disk value '$override' (want <name>=/dev/..., e.g. hdd-d=/dev/disk/by-id/...)"
        exit 1
    fi
    OVERRIDE_ATTRS+="\"$name\".device = lib.mkForce \"$device\"; "
done
HOST_EXPR="((builtins.getFlake \"git+file://$DOTFILES_DIR\").nixosConfigurations.\"$HOSTNAME\".extendModules { modules = [ ({ lib, ... }: { disko.devices.disk = { $OVERRIDE_ATTRS}; }) ]; })"

nix_x() { nix --experimental-features "nix-command flakes" "$@"; }

# Name every disk the host declares, so the confirmation below is about real devices rather
# than an abstract "the target disk". On mimir that list is five disks, four of them /data.
log_info "Disks declared by $HOSTNAME:"
DECLARED_DISKS=$(nix_x eval --impure --raw --expr "$HOST_EXPR.config.disko.devices.disk" \
    --apply 'ds: builtins.concatStringsSep "\n" (builtins.attrValues (builtins.mapAttrs (n: d: n + " " + d.device) ds))')
for override in "${DISK_OVERRIDES[@]}"; do
    if ! grep -q "^${override%%=*} " <<<"$DECLARED_DISKS"; then
        log_error "--disk ${override%%=*}: $HOSTNAME declares no disk by that name"
        exit 1
    fi
done
while read -r name device; do
    echo "  - $name: $device -> $(readlink -f "$device")"
done <<<"$DECLARED_DISKS"
echo ""

# ---- Preflight: refuse to let disko touch a disk the layout does not mean ------------------
#
# Hosts declare disks as /dev/sdX, and those names are handed out in probe order. The installer
# stick is a SCSI-class disk too: on mimir it came up as /dev/sdd — hdd-d's name — and disko
# went at it; only the ISO9660 image not being a valid GPT stopped sgdisk. So nothing is touched
# until every declared disk is present, distinct, internal, and not the medium we booted from.
live_disk=""
if iso_src=$(findmnt -no SOURCE /iso 2>/dev/null) && [[ -n "$iso_src" ]]; then
    live_disk=$(lsblk -no PKNAME "$iso_src" 2>/dev/null | head -n1)
    [[ -n "$live_disk" ]] || live_disk=$(basename "$iso_src")
fi

preflight_errors=()
declare -A seen_disks=()
while read -r name device; do
    real=$(readlink -f "$device")
    base=$(basename "$real")
    if [[ ! -b "$real" ]]; then
        preflight_errors+=("$name: $device does not exist")
        continue
    fi
    if [[ "$(lsblk -dno TYPE "$real")" != "disk" ]]; then
        preflight_errors+=("$name: $device is not a whole disk")
        continue
    fi
    if [[ -n "${seen_disks[$real]:-}" ]]; then
        preflight_errors+=("$name: $device is the same disk as ${seen_disks[$real]}")
    fi
    seen_disks[$real]="$name"
    if [[ -n "$live_disk" && "$base" == "$live_disk" ]]; then
        preflight_errors+=("$name: $device is the installer USB stick this system booted from")
    elif [[ "$(lsblk -dno TRAN "$real" | tr -d ' ')" == "usb" || "$(cat "/sys/block/$base/removable" 2>/dev/null)" == "1" ]]; then
        preflight_errors+=("$name: $device is a USB/removable device, not an internal disk")
    elif [[ "$(blkid -o value -s TYPE "$real" 2>/dev/null)" == "iso9660" ]]; then
        preflight_errors+=("$name: $device holds an ISO9660 image (an installer stick?)")
    fi
done <<<"$DECLARED_DISKS"

if [[ ${#preflight_errors[@]} -gt 0 ]]; then
    log_error "Refusing to partition: the declared disks do not match this machine."
    for e in "${preflight_errors[@]}"; do
        echo "    - $e"
    done
    echo ""
    log_info "Whole disks present (match them by SIZE / MODEL / SERIAL):"
    lsblk -d -e 7 -o NAME,SIZE,TRAN,RM,MODEL,SERIAL
    echo ""
    log_info "Their stable names:"
    find /dev/disk/by-id -maxdepth 1 -type l ! -name '*-part*' ! -name 'wwn-*' ! -name 'nvme-eui.*' ! -name 'dm-*' \
        -printf '  /dev/disk/by-id/%f -> %l\n' 2>/dev/null | sed 's|-> \.\./\.\./|-> |' | sort -k3
    echo ""
    log_info "Re-run naming the right device for each disk above, e.g.:"
    echo "    install-nixos $HOSTNAME ${WIPE:+--wipe }--disk <name>=/dev/disk/by-id/<id>"
    exit 1
fi
log_success "Preflight: every declared disk is present, distinct and internal"
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
    script=$(nix_x build --impure --no-link --print-out-paths \
        --expr "$HOST_EXPR.config.system.build.destroyFormatMount")
    "$script/bin/disko-destroy-format-mount" --yes-wipe-all-disks
else
    script=$(nix_x build --impure --no-link --print-out-paths \
        --expr "$HOST_EXPR.config.system.build.formatMount")
    "$script/bin/disko-format-mount"
fi

log_success "Disk partitioned and mounted"

# Generate hardware configuration (optional, we have our own)
# nixos-generate-config --root /mnt

# Copy dotfiles to the new system
log_info "Setting up dotfiles in new system..."
mkdir -p /mnt/home/tom
# A non-destructive reinstall keeps the old root filesystem, and with it the old
# ~/.dotfiles. Features link user config (nushell's env.nu, …) into that checkout, so
# a stale one breaks the new system: on mimir an August checkout sourced a starship.nu
# the current config no longer ships, nushell failed as the login shell, and GDM
# bounced every login back to the greeter. `cp -r` onto an existing directory would
# also nest the fresh copy inside the stale one instead of replacing it. Move the old
# checkout aside, keeping it in case it held uncommitted work, and copy the fresh one.
if [[ -e /mnt/home/tom/.dotfiles ]]; then
    stale="/mnt/home/tom/.dotfiles.pre-install-$(date +%Y%m%d-%H%M%S)"
    log_warn "Existing ~/.dotfiles found in the target; moving it to ${stale#/mnt}"
    mv /mnt/home/tom/.dotfiles "$stale"
fi
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
