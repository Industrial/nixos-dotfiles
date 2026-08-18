#!/usr/bin/env bash
# Launch a nested Hyprland session with Caelestia Shell (tryout).
# Requires an existing Wayland session (outer Hyprland or GNOME).
# Prefer the Nix-wrapped binary nested-caelestia-hyprland (fixed config path).
set -euo pipefail

if [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
  echo "nested-caelestia-hyprland: need a parent Wayland session (WAYLAND_DISPLAY unset)" >&2
  exit 1
fi

CONFIG="${NESTED_CAELESTIA_HYPR_CONFIG:-}"
if [[ -z "${CONFIG}" ]]; then
  echo "nested-caelestia-hyprland: set NESTED_CAELESTIA_HYPR_CONFIG to hyprland-nested-caelestia.lua" >&2
  exit 1
fi

if [[ ! -f "${CONFIG}" ]]; then
  echo "nested-caelestia-hyprland: config not found: ${CONFIG}" >&2
  exit 1
fi

if ! command -v Hyprland >/dev/null 2>&1; then
  echo "nested-caelestia-hyprland: Hyprland not on PATH" >&2
  exit 1
fi

echo "nested-caelestia-hyprland: starting nested Hyprland with ${CONFIG}"
exec Hyprland --config "${CONFIG}"
