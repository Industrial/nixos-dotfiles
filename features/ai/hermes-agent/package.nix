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
  # List of extra Python packages (plugins) to inject as propagatedBuildInputs.
  # Each must declare a [project.entry-points."hermes_agent.plugins"] entry point
  # so Hermes discovers it via importlib.metadata at session start.
  extraPlugins ? [],
}:
python3Packages.buildPythonApplication rec {
  pname = "hermes-agent";
  version = "0.18.0";
  revision = "v2026.7.1";

  # Release "Hermes Agent v0.18.0 (2026.7.1)" — tag is calendar-style, not v0.18.0.
  src = fetchFromGitHub {
    owner = "NousResearch";
    repo = "hermes-agent";
    rev = revision;
    hash = "sha256-Wt72AQtA6Eizi7Ubj23JBhwZ7GKYcjY4mcV6upqHOaU=";
  };

  pyproject = true;
  build-system = with python3Packages; [setuptools];

  # nixpkgs-unstable ships setuptools 83; upstream caps <83 in [build-system].requires.
  postPatch = ''
    substituteInPlace pyproject.toml --replace-fail \
      "setuptools>=77.0,<83" \
      "setuptools>=77.0"
  '';

  # mcp is an optional extra ("extra == mcp") so buildPythonApplication's dep resolution skips
  # it. Inject it explicitly via propagatedBuildInputs so it lands in the runtime closure.
  propagatedBuildInputs = with python3Packages;
    [mcp]
    ++ extraPlugins;

  # Core [project].dependencies plus anthropic (optional extra upstream; required for provider=anthropic).
  # Other lazy backends stay in pythonRemoveDeps until we add explicit outputs or deps for them.
  dependencies =
    (with python3Packages; [
      openai
      certifi
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
      packaging
      markdown
      pyjwt
      urllib3
      cryptography
      psutil
      websockets
      pathspec
      fastapi
      uvicorn
      python-multipart
      ptyprocess
      pillow
      anthropic
      mcp
    ])
    ++ lib.optionals (python3Packages.python.stdenv.hostPlatform.isWindows) [python3Packages.tzdata];

  pythonImportsCheck = ["hermes_cli"];

  # Upstream pins == in pyproject; nixpkgs may carry slightly different versions.
  pythonRelaxDeps = [
    "openai"
    "certifi"
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
    "packaging"
    "markdown"
    "pyjwt"
    "urllib3"
    "cryptography"
    "psutil"
    "websockets"
    "pathspec"
    "fastapi"
    "uvicorn"
    "python-multipart"
    "ptyprocess"
    "pillow"
    "anthropic"
    "mcp"
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
