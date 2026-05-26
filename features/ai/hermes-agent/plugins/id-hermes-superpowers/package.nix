# id-hermes-superpowers — Nix package for the Superpowers Hermes plugin
#
# Builds the Python package and registers it as a hermes_agent.plugins
# entry point so Hermes discovers it via importlib.metadata at session start.
#
# Consumed by hermes-agent/default.nix via propagatedBuildInputs on the
# main hermes-agent package (see the comment there).
#
# Bump version and hash when pyproject.toml version changes.
{
  lib,
  python3Packages,
}:
python3Packages.buildPythonPackage {
  pname = "id-hermes-superpowers";
  version = "0.1.0";

  # The plugin lives in-tree; src is the plugin directory itself.
  src = ./.;

  pyproject = true;
  build-system = with python3Packages; [setuptools];

  # No runtime deps yet — extend this list as tools.py gains imports.
  dependencies = [];

  # Nothing to import at build time beyond the package itself.
  pythonImportsCheck = ["id_hermes_superpowers"];

  # Tests live alongside the plugin — skip until a test suite is added.
  doCheck = false;

  meta = {
    description = "Superpowers agentic development workflows for Hermes Agent";
    homepage = "https://github.com/obra/superpowers";
    license = lib.licenses.mit;
    maintainers = [];
    platforms = lib.platforms.unix;
  };
}
