systems: {
  inputs,
  self,
  ...
}: {
  matrix = inputs.nix-github-actions.lib.mkGithubMatrix {
    checks = inputs.nixpkgs.lib.getAttrs systems self.checks;
  };
}
