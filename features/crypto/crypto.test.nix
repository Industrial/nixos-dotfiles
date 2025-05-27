{pkgs, ...}: {
  bisq = import ./bisq/bisq.test.nix {inherit pkgs;};
  monero = import ./monero/monero.test.nix {inherit pkgs;};
}
