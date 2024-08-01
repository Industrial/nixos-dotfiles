nixpkgs: f:
nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed (system:
    f {
      inherit system;
      pkgs = import nixpkgs {
        inherit system;
        config = {allowUnfree = true;};
      };
    })
