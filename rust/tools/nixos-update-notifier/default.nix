# Make nixos-update-notifier available as a Nix package (buildRustPackage).
{
  lib,
  rustPlatform,
  pkg-config,
  makeWrapper,
  nix,
  git,
  coreutils,
  util-linux,
}:
rustPlatform.buildRustPackage {
  pname = "nixos-update-notifier";
  version = "0.1.0";

  src = ./.;

  cargoLock.lockFile = ./Cargo.lock;

  nativeBuildInputs = [
    pkg-config
    makeWrapper
  ];

  # notify-rust / zbus talk to the session bus at runtime; no link-time dbus needed.

  postInstall = ''
    wrapProgram $out/bin/nixos-update-notifier \
      --prefix PATH : ${lib.makeBinPath [nix git coreutils util-linux]}
  '';

  meta = with lib; {
    description = "Notify when NixOS flake updates are available, listing exact package changes";
    license = licenses.mit;
    mainProgram = "nixos-update-notifier";
    platforms = platforms.linux;
  };
}
