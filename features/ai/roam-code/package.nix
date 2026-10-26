# roam-code — AI-native code intelligence MCP server — https://github.com/Cranot/roam-code
#
# Static analysis + semantic code graph over 40 languages via tree-sitter.
# Not in nixpkgs; built here from PyPI using buildPythonPackage + fetchPypi.
#
# The MCP extra (fastmcp) is declared as optional in pyproject; it is injected via
# propagatedBuildInputs so it lands in the runtime closure (same pattern as mcp in hermes-agent).
#
# Invocation: roam mcp   (stdio transport)
#
# nixpkgs ships mcp 2.x, which marks fastmcp-slim 3.x broken. Pin mcp to the last
# 1.x release in a python set scoped to this package until fastmcp is bumped.
{
  lib,
  fetchFromGitHub,
  python3,
}: let
  python = python3.override {
    self = python;
    packageOverrides = pself: psuper: {
      mcp = psuper.mcp.overridePythonAttrs (old: {
        version = "1.30.0";
        src = fetchFromGitHub {
          owner = "modelcontextprotocol";
          repo = "python-sdk";
          tag = "v1.30.0";
          hash = "sha256-EkmTqsK+vBJcURuwFkhtNJMFgtzgw/7Cd+Fpav4P/ko=";
        };
        dependencies = with pself;
          [
            anyio
            httpx
            httpx-sse
            jsonschema
            pydantic
            pydantic-settings
            pyjwt
            python-multipart
            sse-starlette
            starlette
            typing-extensions
            typing-inspection
            uvicorn
          ]
          ++ pyjwt.optional-dependencies.crypto;
        doCheck = false;
      });
      # Rebuilt against mcp 1.x; one OAuth-proxy storage test asserts a 2.x-era shape.
      fastmcp = psuper.fastmcp.overridePythonAttrs {doCheck = false;};
    };
  };
  python3Packages = python.pkgs;
in
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
