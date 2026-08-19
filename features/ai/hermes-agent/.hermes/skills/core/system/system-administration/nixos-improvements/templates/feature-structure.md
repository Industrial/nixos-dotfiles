# Standard NixOS Feature Structure

For each feature in `features/<category>/<name>/`:

## Required Files
- `package.nix` - Defines the package using buildRustPackage or similar
- `default.nix` - Includes the package in environment.systemPackages

## Optional Files
- `default.assay.nix` - Assay unit tests for the feature

## Examples

package.nix:
```nix
{ lib, pkgs, ... }: 
  pkgs.buildRustPackage rec {
    pname = "<featurename>";
    version = "<version>";

    src = pkgs.fetchFromGitHub {
      owner = "<owner>";
      repo = "<repo>";
      rev = "<rev>";
      sha256 = "<sha256>";
    };

    # ... other package configuration

    meta = {
      description = "<description>";
      homepage = "<homepage>";
      license = lib.licenses.<license>;
      platforms = pkgs.platforms.linux;
      maintainers = [pkgs.maintainers.unknown];
    };
  }
```

default.nix:
```nix
{ lib, pkgs, ... }:
{
  environment.systemPackages = [ (pkgs.callPackage ./package.nix {}) ];
}
```

default.assay.nix:
```nix
let
  assay = import ./../../../common/assay/default.nix;
  mod = let
    pkgs = {
      <featurename> = "<featurename>";
    };
  in
    import ./default.nix {inherit pkgs;};
in
  assay.suite "<featurename>" {
    systemPackages = assay.eq mod.environment.systemPackages ["<featurename>"];
  }
```
```