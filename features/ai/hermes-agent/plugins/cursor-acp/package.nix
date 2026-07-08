# cursor-acp — Cursor CLI ACP model-provider plugin for Hermes Agent
#
# Registers the CursorACPProfile so Hermes can route conversations through
# `cursor agent acp` using the user's existing Cursor subscription.
# No upstream source to pin — the plugin is pure Python, no external assets.
{
  lib,
  python3Packages,
}:
python3Packages.buildPythonPackage {
  pname = "cursor-acp";
  version = "0.1.0";

  src = ./.;

  pyproject = true;
  build-system = with python3Packages; [setuptools];

  # Provider registration is pure Python against Hermes internals at runtime.
  # No additional deps needed.
  dependencies = [];

  pythonImportsCheck = []; # providers module is a hermes-agent internal — only resolvable at runtime
  doCheck = false;

  meta = {
    description = "Cursor CLI ACP model-provider plugin for Hermes Agent";
    homepage = "https://cursor.com";
    license = lib.licenses.mit;
    maintainers = [];
    platforms = lib.platforms.unix;
  };
}
