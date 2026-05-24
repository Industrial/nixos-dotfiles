{
  pkgs,
  lib,
  stdenv,
  buildGoModule,
  fetchFromGitHub,
  installShellFiles,
  gitMinimal,
  writableTmpDirAsHomeHook,
  ...
}: let
  beadsAppVersion = "1.0.4";

  beadsPackage = pkgs.buildGoModule rec {
    pname = "beads";
    version = beadsAppVersion;

    src = pkgs.fetchFromGitHub {
      owner = "steveyegge";
      repo = "beads";
      tag = "v${beadsAppVersion}";
      sha256 = "sha256-a356lk3dWJg2VzXmvBL0xVYUMgICDY/6s6A5km8cjBU=";
    };

    vendorHash = "sha256-gTOYABrdQ9T5uxW5QEE8hRWH6AnCPFE/hbB2t1OJTrY=";

    subPackages = ["cmd/bd"];

    ldflags = [
      "-s"
      "-w"
    ];

    buildInputs = [pkgs.icu];

    nativeBuildInputs = [
      pkgs.installShellFiles
    ];

    # Upstream hook/worktree tests need git sandbox affordances we do not provide here.
    doCheck = false;

    meta = {
      description = "Lightweight memory system for AI coding agents with graph-based issue tracking";
      homepage = "https://github.com/steveyegge/beads";
      license = lib.licenses.mit;
      maintainers = [lib.maintainers.steveyegge];
      mainProgram = "bd";
      platforms = lib.platforms.unix;
    };
  };
in {
  environment = {
    systemPackages = with pkgs; [
      beadsPackage
    ];
  };
}
