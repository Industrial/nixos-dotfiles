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
{
  pkgs,
  lib,
  ...
}: let
  version = "1.12.1";

  inherit (pkgs.stdenv.hostPlatform) system;

  supported = system == "x86_64-linux" || system == "aarch64-linux";

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
    extraPkgs = pkgs: with pkgs; [gzip];
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
