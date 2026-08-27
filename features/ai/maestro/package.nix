# maestro — Local-first agent harness for the spec-to-ship loop
# https://github.com/ReinaMacCredy/maestro
#
# v0.106.1 ships prebuilt release binaries for linux-x64, linux-arm64, darwin-x64, darwin-arm64.
# The linux-x64 binary is fetched directly from the GitHub release and placed on PATH.
# No Bun dependency at runtime — the binary is self-contained.
#
# Hermes integration note: maestro ships 6 bundled skills (maestro-task, maestro-verify,
# maestro-handoff, etc.) that sync into agent roots via `maestro install`. This Nix package
# makes the CLI available system-wide; the skills live in the user's .maestro/ workspace once
# `maestro init` has been run in a project.
#
# Version policy:
# - Track the latest stable release tag from https://github.com/ReinaMacCredy/maestro/releases/latest
# - Update `version` and `sha256` together; the download URL embeds the version.
# - To update, replace the sha256 below with lib.fakeHash, run `nix-build . -A maestro`,
#   and copy the reported "got: sha256:..." hash into this file.
#
# Ported from ~/.dotfiles/features/ai/maestro/package.nix (NixOS module → devenv feature).
{
  lib,
  stdenv,
  fetchurl,
  patchelf,
}:
stdenv.mkDerivation rec {
  pname = "maestro";
  version = "0.106.1";

  src = fetchurl {
    url = "https://github.com/ReinaMacCredy/maestro/releases/download/v${version}/maestro-linux-x64";
    sha256 = "eafe30209e6f6767f8bb62600e6f93f1d600a5c7ea4267d83abc2e58980793fc";
  };

  dontUnpack = true;
  dontBuild = true;
  # stdenv fixup shrinks/strips ELF metadata and breaks Bun standalone layouts.
  dontShrinkRpath = true;
  dontStrip = true;
  nativeBuildInputs = [patchelf];

  # Bun-compiled release binaries embed a virtual filesystem; autoPatchelfHook
  # rewrites RPATH/libs and leaves a runnable `bun` on PATH instead of maestro.
  installPhase = ''
    install -D -m755 $src $out/bin/maestro
    patchelf --set-interpreter ${stdenv.cc.bintools.dynamicLinker} $out/bin/maestro
  '';

  meta = {
    description = "Local-first agent harness for the spec-to-ship loop (maestro v${version})";
    homepage = "https://github.com/ReinaMacCredy/maestro";
    changelog = "https://github.com/ReinaMacCredy/maestro/releases/tag/v${version}";
    license = lib.licenses.mit;
    maintainers = [];
    mainProgram = "maestro";
    platforms = lib.platforms.linux;
  };
}
