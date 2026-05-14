# roam-code — AI-native code intelligence MCP server — https://github.com/Cranot/roam-code
#
# Static analysis + semantic code graph over 40 languages via tree-sitter.
# Not in nixpkgs; built here from PyPI using buildPythonPackage + fetchPypi.
#
# The MCP extra (fastmcp) is declared as optional in pyproject; it is injected via
# propagatedBuildInputs so it lands in the runtime closure (same pattern as mcp in hermes-agent).
#
# Invocation: roam mcp   (stdio transport)
{
  lib,
  python3Packages,
}:
python3Packages.buildPythonPackage rec {
  pname = "roam-code";
  version = "13.0";

  src = python3Packages.fetchPypi {
    pname = "roam_code";
    inherit version;
    hash = "sha256-M1QJ0742yaBhpZG1eFwX+s+e0tyo0QTy9P+ltzFsMBU=";
  };

  pyproject = true;
  build-system = with python3Packages; [setuptools];

  # fastmcp is the "mcp" optional extra — inject explicitly so it enters the runtime closure.
  propagatedBuildInputs = with python3Packages; [fastmcp];

  dependencies = with python3Packages; [
    click
    tree-sitter
    tree-sitter-language-pack
    networkx
  ];

  pythonRelaxDeps = [
    "click"
    "tree-sitter"
    "tree-sitter-language-pack"
    "networkx"
    "fastmcp"
  ];

  doCheck = false;

  meta = {
    description = "AI-native code intelligence MCP server with tree-sitter graph analysis";
    homepage = "https://github.com/Cranot/roam-code";
    changelog = "https://github.com/Cranot/roam-code/blob/main/CHANGELOG.md";
    license = lib.licenses.mit; # client code is MIT; service terms apply for cloud features
    maintainers = [];
    mainProgram = "roam";
    platforms = lib.platforms.unix;
  };
}
