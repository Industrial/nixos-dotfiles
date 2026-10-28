# V-268152 (CAT II) — NixOS must prohibit user installation of system software without
# explicit privileged status.
#
# Fix text: nix.settings.allowed-users = [ "root" "@wheel" ];
#
# Restricts who may talk to the nix daemon. The nixpkgs default is `[ "*" ]`, so this is a
# real change: any account not in wheel loses `nix build`, `nix shell`, `nix-env` and every
# devenv shell.
#
# `full` profile. On a single-operator workstation the practical effect is small because the
# operator is in wheel, but it breaks service accounts and any CI runner that builds as a
# non-wheel user — which is why it is not base-safe.
{...}: {
  nix.settings.allowed-users = ["root" "@wheel"];
}
