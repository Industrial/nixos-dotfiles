{pkgs, ...}: {
  ai = import ./ai/ai.test.nix {inherit pkgs;};
  ci = import ./ci/ci.test.nix {inherit pkgs;};
  cli = import ./cli/cli.test.nix {inherit pkgs;};
  communication = import ./communication/communication.test.nix {inherit pkgs;};
  crypto = import ./crypto/crypto.test.nix {inherit pkgs;};
  games = import ./games/games.test.nix {inherit pkgs;};
  media = import ./media/media.test.nix {inherit pkgs;};
  programming = import ./programming/programming.test.nix {inherit pkgs;};
}
