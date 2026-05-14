# serena-agent — AI coding agent with LSP-based code intelligence MCP server
# https://github.com/oraios/serena
#
# Not in nixpkgs; built here from PyPI using buildPythonPackage + fetchPypi.
# Version 1.3.0 upstream uses pinned == deps; pythonRelaxDeps = true relaxes all of them.
#
# Three deps are removed entirely because they are either not in nixpkgs or are
# subprocess-invoked tools (not Python imports at runtime):
#   - dotenv: a thin shim that re-exports python-dotenv; python-dotenv is already present
#   - pyright: node binary invoked as a subprocess for type-checking; not a Python import
#   - fortls: Fortran LSP; not needed for MCP / Python projects
#
# Invocation: serena start-mcp-server  (stdio transport, no --project required for global use)
{
  lib,
  python3Packages,
}:
python3Packages.buildPythonPackage rec {
  pname = "serena-agent";
  version = "1.3.0";

  src = python3Packages.fetchPypi {
    pname = "serena_agent";
    inherit version;
    hash = "sha256-uYXeJoJ0mZ/YrGN1T5ezAaLKIfyavLQ67fc03/wTJoI=";
  };

  pyproject = true;
  build-system = with python3Packages; [hatchling];

  dependencies = with python3Packages; [
    anthropic
    beautifulsoup4
    cryptography
    docstring-parser
    filelock
    flask
    jinja2
    joblib
    lsprotocol
    mcp
    overrides
    pathspec
    psutil
    pydantic
    pygls
    pystray
    python-dotenv
    python-multipart
    pyyaml
    regex
    requests
    ruamel-yaml
    sensai-utils
    starlette
    tiktoken
    tqdm
    types-pyyaml
    urllib3
    werkzeug
  ];

  # 1.3.0 ships with pinned == versions; relax all so nixpkgs versions are accepted.
  pythonRelaxDeps = true;

  # dotenv is a pure shim over python-dotenv (already present above).
  # pyright and fortls are subprocess tools, not Python imports — both absent from nixpkgs.
  pythonRemoveDeps = [
    "dotenv"
    "pyright"
    "fortls"
    "pywebview"
  ];

  doCheck = false;

  meta = {
    description = "AI coding agent with LSP-based code intelligence and MCP server";
    homepage = "https://github.com/oraios/serena";
    changelog = "https://github.com/oraios/serena/releases";
    license = lib.licenses.mit;
    maintainers = [];
    mainProgram = "serena";
    platforms = lib.platforms.unix;
  };
}
