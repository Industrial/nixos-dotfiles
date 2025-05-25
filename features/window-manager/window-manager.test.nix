{pkgs, ...}: {
  dwm-status = import ./dwm-status/dwm-status.test.nix {inherit pkgs;};
}
