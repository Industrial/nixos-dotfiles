# Make nixos-update-notifier available as a Nix package (buildRustPackage), called
# with callPackage from features/cli/nixos-update-notifier like the other crates.
#
# vdiff (rust/tools/vdiff) lists the package changes (`vdiff --json`, GH-207). The
# wrapper points NIXOS_UPDATE_VDIFF at its absolute store path; `--differ nix`
# (NIXOS_UPDATE_DIFFER=nix) is the rollback to `nix store diff-closures`.
{
  lib,
  callPackage,
  rustPlatform,
  pkg-config,
  makeWrapper,
  nix,
  git,
  coreutils,
  util-linux,
  curl,
  vdiff ? callPackage ../vdiff/default.nix {},
}:
rustPlatform.buildRustPackage {
  pname = "nixos-update-notifier";
  version = "0.1.0";

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./Cargo.toml
      ./Cargo.lock
      ./src
      # The vdiff --json captures the parser tests read.
      ./tests/fixtures
    ];
  };

  cargoLock.lockFile = ./Cargo.lock;

  nativeBuildInputs = [
    pkg-config
    makeWrapper
  ];

  # notify-rust / zbus talk to the session bus at runtime; no link-time dbus needed.

  postInstall = ''
    wrapProgram $out/bin/nixos-update-notifier \
      --prefix PATH : ${lib.makeBinPath [nix git coreutils util-linux curl]} \
      --set-default NIXOS_UPDATE_VDIFF ${lib.getExe vdiff}
  '';

  passthru = {inherit vdiff;};

  meta = with lib; {
    description = "Notify when NixOS flake updates are available, listing exact package changes";
    license = licenses.mit;
    mainProgram = "nixos-update-notifier";
    platforms = platforms.linux;
  };
}
