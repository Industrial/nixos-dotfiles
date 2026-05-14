# Hermes Agent — https://hermes-agent.org/ — https://github.com/NousResearch/hermes-agent
#
# Upstream ships a curl|bash installer (uv + Python). For Nix we use fetchFromGitHub +
# buildPythonApplication, matching patterns used in nixpkgs for setuptools + pyproject apps.
#
# Version policy:
# - `version` follows the Python package version in pyproject.toml at the pinned `rev`.
# - `rev` is the immutable GitHub release tag (upstream often uses calendar tags, not semver).
# Bump both together when upgrading; verify pyproject `[project].version` matches `version`.
{
  lib,
  python3Packages,
  fetchFromGitHub,
}:
python3Packages.buildPythonApplication rec {
  pname = "hermes-agent";
  version = "0.13.0";

  # Release "Hermes Agent v0.13.0 (2026.5.7)" — tag is calendar-style, not v0.13.0.
  src = fetchFromGitHub {
    owner = "NousResearch";
    repo = "hermes-agent";
    rev = "v2026.5.7";
    hash = "sha256-YQQUEDUim2CiYpL3uG7Wi1fWPsT2wtIqoBeJuAj9hUk=";
  };

  pyproject = true;
  build-system = with python3Packages; [setuptools];

  # Core [project].dependencies plus anthropic (optional extra upstream; required for provider=anthropic).
  # Other lazy backends stay in pythonRemoveDeps until we add explicit outputs or deps for them.
  dependencies =
    (with python3Packages; [
      openai
      python-dotenv
      fire
      httpx
      socksio
      pysocks
      rich
      tenacity
      pyyaml
      ruamel-yaml
      requests
      jinja2
      pydantic
      prompt-toolkit
      croniter
      pyjwt
      cryptography
      psutil
      anthropic
    ])
    ++ lib.optionals (python3Packages.python.stdenv.hostPlatform.isWindows) [python3Packages.tzdata];

  pythonImportsCheck = ["hermes_cli"];

  # Upstream pins == in pyproject; nixpkgs may carry slightly different versions.
  pythonRelaxDeps = [
    "openai"
    "python-dotenv"
    "fire"
    "httpx"
    "rich"
    "tenacity"
    "pyyaml"
    "ruamel.yaml"
    "requests"
    "jinja2"
    "pydantic"
    "prompt-toolkit"
    "croniter"
    "pyjwt"
    "cryptography"
    "psutil"
    "anthropic"
  ];

  # Upstream loads these via tools/lazy_deps.py; they are not true core imports but
  # still appear as Requires-Dist on the built wheel, which breaks pythonRuntimeDepsCheck.
  pythonRemoveDeps = [
    "exa-py"
    "parallel-web"
    "fal-client"
    "edge-tts"
  ];

  meta = {
    description = "Self-hosted AI agent with persistent memory, skills, and multi-platform gateway";
    homepage = "https://hermes-agent.org/";
    changelog = "https://github.com/NousResearch/hermes-agent/releases";
    license = lib.licenses.mit;
    maintainers = []; # fill when submitting to nixpkgs
    mainProgram = "hermes";
    platforms = python3Packages.python.meta.platforms;
  };
}
