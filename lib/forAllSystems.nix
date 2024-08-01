nixpkgs: systems: f:
nixpkgs.lib.genAttrs systems (system:
    f {
      inherit system;
      pkgs = import nixpkgs {
        inherit system;
        config = {allowUnfree = true;};
      };
    })
