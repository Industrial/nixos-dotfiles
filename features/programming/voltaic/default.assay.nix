# Colocated suite: voltaic compiler, language server and MCP server from the
# flake input.
let
  assay = import ./../../../common/assay/default.nix;
  mod = import ./default.nix {
    inputs.voltaic.packages."x86_64-linux".voltaic = "voltaic-pkg";
    pkgs.stdenv.hostPlatform.system = "x86_64-linux";
  };
in
  assay.suite "voltaic" {
    # One derivation, not three: `voltaic`, `voltaic-lsp` and `voltaic-mcp` share
    # almost their whole dependency graph, so the flake aliases them and this
    # module asks for the one package.
    installsOnePackage = assay.eq (builtins.length mod.environment.systemPackages) 1;

    # Selected per host platform from the flake input, not hardcoded to one
    # system.
    selectsPackageForHostPlatform = assay.eq mod.environment.systemPackages ["voltaic-pkg"];
  }
