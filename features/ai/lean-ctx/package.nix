# lean-ctx — context engineering layer for agents (MCP server + CLI).
# https://github.com/yvgude/lean-ctx
#
# A pinned release binary rather than a source build: nixpkgs' rustc cannot build
# rten-gemm (AVX512 VNNI intrinsic mismatch on rustc 1.97+).
#
# Ported from .cursor/nix/features/program-lean-ctx.nix (devenv feature -> NixOS module).
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
}:
stdenv.mkDerivation {
  pname = "lean-ctx";
  version = "3.9.18";

  src = fetchurl {
    url = "https://github.com/yvgude/lean-ctx/releases/download/v3.9.18/lean-ctx-x86_64-unknown-linux-gnu.tar.gz";
    hash = "sha256-jjZ2sqM5TjN4Faj+Uqo9VtR/GY/60mbHg+uHDnqeZng=";
  };

  nativeBuildInputs = [autoPatchelfHook];
  buildInputs = [stdenv.cc.cc.lib];
  sourceRoot = ".";

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    install -m755 lean-ctx $out/bin/lean-ctx
    runHook postInstall
  '';

  meta = {
    description = "lean-ctx MCP + CLI (pinned GitHub release)";
    homepage = "https://github.com/yvgude/lean-ctx";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
