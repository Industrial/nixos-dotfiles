# Colocated suite: alacritty on systemPackages.
let
  assay = import ./../../../common/assay/default.nix;
  mod = import ./default.nix {
      settings = { hostname = "h"; username = "alice"; };
      pkgs = {
        alacritty = "alacritty";
        writeTextFile = args: args.name;
      };
    };

in
  assay.suite "alacritty" {
    packages = assay.eq mod.environment.systemPackages [ "alacritty" ];
  }
