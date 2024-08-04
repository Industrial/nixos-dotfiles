{
  pkgs,
  self,
  system,
}: {
  default = pkgs.mkShell {
    # inherit (self.checks.${system}.pre-commit-check) shellHook;
    # buildInputs = self.checks.${system}.pre-commit-check.enabledPackages;
    inputsFrom = [];
    packages = with pkgs; [
      direnv
    ];
  };
}
