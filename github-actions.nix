{
  inputs,
  self,
  ...
}:
inputs.nix-github-actions.lib.mkGithubMatrix {
  checks = inputs.nixpkgs.lib.getAttrs ["x86_64-linux" "aarch64-darwin"] self.checks;
}
