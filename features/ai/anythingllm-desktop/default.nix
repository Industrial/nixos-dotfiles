# AnythingLLM Desktop — official Linux AppImage wrapped for NixOS (FHS).
#
# Upstream installer (what this mirrors):
#   curl -fsSL https://cdn.anythingllm.com/latest/installer.sh
# Docs: https://docs.anythingllm.com/installation-desktop/linux
# Product page: https://anythingllm.com/desktop
#
# The installer script downloads one of:
#   x86_64:    https://cdn.anythingllm.com/latest/AnythingLLMDesktop.AppImage
#   aarch64:   https://cdn.anythingllm.com/latest/AnythingLLMDesktop-Arm64.AppImage
# and optionally writes AppArmor + a user .desktop file. Here we use
# pkgs.appimageTools.wrapType2 (extract + FHS) like other AppImage features in
# this repo; AppArmor rules in the installer target a bare *.AppImage path and
# are not applied automatically — use upstream docs if you run the raw AppImage.
#
# CDN uses /latest/ (no per-version URL). When the vendor updates the image,
# fixed-output hashes below will fail to match: run the prefetch command in the
# error, update `version` (match https://github.com/Mintplex-Labs/anything-llm/releases),
# and paste the new hashes. aarch64 still uses lib.fakeHash until prefetched on
# that platform.
#
# Known NixOS caveats (upstream / Prisma): see Mintplex-Labs/anything-llm#4533.
# `gzip` is included in the FHS env so bundled tooling can run `gunzip`.
#
# Prisma does not ship query engines for `linux-nixos`; the download URL returns
# 404 HTML (~27KiB), which the app saves as `.gz` and `gunzip` rejects. The app
# picks that target from `/etc/os-release` (`ID=nixos`). Do not use
# `extraBwrapArgs` with `--ro-bind`/`--symlink` on `/etc/os-release`: those run
# after host `/etc/*` links and bubblewrap’s bind path hits “Can't create file at
# /etc/os-release”. Instead add a tiny package via `extraPkgs` so `etc/os-release`
# is merged into the FHS rootfs and `--ro-bind`’d in the normal early phase;
# `etc_ignored` then skips the host NixOS os-release. Stale Prisma HTML:
#   rm -rf ~/.config/anythingllm-desktop/storage/.prisma/engines
# `nixos-rebuild boot` alone leaves `/run/current-system` stale until reboot or
# `nixos-rebuild switch`.
{
  pkgs,
  lib,
  ...
}: let
  version = "1.12.1";

  inherit (pkgs.stdenv.hostPlatform) system;

  supported = system == "x86_64-linux" || system == "aarch64-linux";

  # Minimal os-release so Prisma/@prisma/get-platform does not select linux-nixos.
  prismaOsRelease = pkgs.writeText "anythingllm-desktop-prisma-os-release" ''
    NAME="Debian GNU/Linux"
    VERSION="12 (bookworm)"
    VERSION_ID="12"
    ID=debian
    VERSION_CODENAME=bookworm
    PRETTY_NAME="Debian GNU/Linux 12 (bookworm)"
  '';

  # Single-file store path merged into the FHS rootfs (not extraBwrapArgs).
  prismaOsReleasePkg = pkgs.runCommand "anythingllm-desktop-prisma-os-etc" {
    meta.priority = -100;
  } ''
    mkdir -p $out/etc
    install -m444 ${prismaOsRelease} $out/etc/os-release
  '';

  appimageUrl =
    if system == "aarch64-linux"
    then "https://cdn.anythingllm.com/latest/AnythingLLMDesktop-Arm64.AppImage"
    else "https://cdn.anythingllm.com/latest/AnythingLLMDesktop.AppImage";

  # Both architectures save the artifact basename as AnythingLLMDesktop.AppImage
  # (installer.sh), which keeps store paths predictable for debugging.
  appimage = pkgs.fetchurl {
    url = appimageUrl;
    name = "AnythingLLMDesktop.AppImage";
    hash =
      if system == "aarch64-linux"
      then lib.fakeHash
      else "sha256-AUQlGyLOKvU15MCjlZj8cP0IjX6CdJDCMYf5fSZH+bk=";
  };

  anythingllm-desktop = pkgs.appimageTools.wrapType2 {
    pname = "anythingllm-desktop";
    inherit version;
    src = appimage;
    extraPkgs = pkgs: with pkgs; [
      gzip
      prismaOsReleasePkg
    ];
    meta = {
      description = "AnythingLLM Desktop — local LLM workspace (official AppImage)";
      homepage = "https://anythingllm.com/desktop";
      license = lib.licenses.mit;
      platforms = ["x86_64-linux" "aarch64-linux"];
    };
  };
in {
  environment.systemPackages = lib.mkIf supported [anythingllm-desktop];
}
