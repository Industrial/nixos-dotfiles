# PLUGIN_NAME — Nix package
# See hermes-agent/package.nix for the extraPlugins wiring.
{
  lib,
  python3Packages,
}:
python3Packages.buildPythonPackage {
  pname = "PLUGIN_NAME";
  version = "0.1.0";
  src = ./.;
  pyproject = true;
  build-system = with python3Packages; [setuptools];
  dependencies = [];
  pythonImportsCheck = ["PLUGIN_PACKAGE"];
  doCheck = false;
  meta = {
    description = "TODO";
    homepage = "";
    license = lib.licenses.mit;
    maintainers = [];
    platforms = lib.platforms.unix;
  };
}
