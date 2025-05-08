{pkgs, ...}: {
  n8n = import ./n8n/n8n.test.nix {inherit pkgs;};
}
