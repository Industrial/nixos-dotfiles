# nix-output-monitor renders Nix build output as a live dependency tree. Binaries: nom, nom-build, nom-shell.
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    nix-output-monitor
  ];
}
