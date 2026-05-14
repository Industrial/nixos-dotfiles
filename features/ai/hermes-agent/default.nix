# Hermes Agent — https://hermes-agent.org/
# Nix-native build (not the upstream curl installer). See package.nix for pins and nixpkgs notes.
{pkgs, ...}: {
  environment.systemPackages = [
    (pkgs.callPackage ./package.nix {})
  ];
}
