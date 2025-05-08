{pkgs, ...}: {
  cli = import ./cli/cli.test.nix {inherit pkgs;};
}
