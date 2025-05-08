{pkgs, ...}: {
  ai = import ./ai/ai.test.nix {inherit pkgs;};
  ci = import ./ci/ci.test.nix {inherit pkgs;};
  cli = import ./cli/cli.test.nix {inherit pkgs;};
}
