{pkgs, ...}: {
  # cli1 = {
  #   testSomeShit = {
  #     expr = true;
  #     expected = true;
  #   };
  # };
  cli = import ./cli/test.nix {inherit pkgs;};
}
