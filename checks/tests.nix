{
  inputs,
  self,
  system,
  ...
}:
inputs.nixpkgs.legacyPackages.${system}.runCommand "tests"
{
  nativeBuildInputs = [inputs.nix-unit.packages.${system}.default];
} ''
  #!/usr/bin/env bash
  export HOME="$(realpath .)"
  # The nix derivation must be able to find all used inputs in the
  # nix-store because it cannot download it during buildTime.
  nix-unit --eval-store "$HOME" \
    --extra-experimental-features flakes \
    --override-input nixpkgs ${inputs.nixpkgs} \
    --flake ${self}#tests
  touch $out
''
