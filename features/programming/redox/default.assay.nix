# Colocated suite: redox compiler, language server and MCP server from the
# flake input.
let
  assay = import ./../../../common/assay/default.nix;
  mod = import ./default.nix {
    inputs.redox.packages."x86_64-linux".redox = "redox-pkg";
    pkgs.stdenv.hostPlatform.system = "x86_64-linux";
  };
in
  assay.suite "redox" {
    # One derivation, not three: `redox`, `redox-lsp` and `redox-mcp` share
    # almost their whole dependency graph, so the flake aliases them and this
    # module asks for the one package.
    installsOnePackage = assay.eq (builtins.length mod.environment.systemPackages) 1;

    # Selected per host platform from the flake input, not hardcoded to one
    # system.
    selectsPackageForHostPlatform = assay.eq mod.environment.systemPackages ["redox-pkg"];
  }
