# id-hermes-superpowers — Superpowers skill pack plugin for Hermes Agent
# https://github.com/obra/superpowers
#
# Option B: fetchFromGitHub pins the upstream repo at a specific rev.
# The skills/ tree is installed into $out/share/id-hermes-superpowers/skills/
# and symlinked into ~/.hermes/skills/superpowers/ at session start via the
# on_session_start hook in id_hermes_superpowers/__init__.py.
#
# To upgrade:
#   1. Get the new rev from: https://github.com/obra/superpowers/commits/main
#   2. Run: nix-prefetch-url --unpack https://github.com/obra/superpowers/archive/<rev>.tar.gz
#   3. Convert: nix hash convert --hash-algo sha256 --to sri <base32-hash>
#   4. Update rev + hash below, bump version to match upstream release tag.
{
  lib,
  stdenv,
  fetchFromGitHub,
  python3Packages,
}:
let
  # Upstream skills source — pinned rev.
  superpowers-src = fetchFromGitHub {
    owner = "obra";
    repo = "superpowers";
    rev = "f2cbfbefebbfef77321e4c9abc9e949826bea9d7"; # v5.1.0 @ 2026-05-04
    hash = "sha256-3E3rO6hR87JUfS3XV1Eaoz6SDWOftleWvN9UPNFEMjw=";
  };
in
python3Packages.buildPythonPackage {
  pname = "id-hermes-superpowers";
  version = "0.1.0";

  src = ./.;

  pyproject = true;
  build-system = with python3Packages; [setuptools];

  # No Python runtime deps yet — extend as tools.py gains imports.
  dependencies = [];

  # Make the pinned upstream skills tree available inside the Python package
  # at the path id_hermes_superpowers/skills/ so the on_session_start hook
  # can resolve it without knowing the Nix store path at runtime.
  postInstall = ''
    skills_dest=$out/${python3Packages.python.sitePackages}/id_hermes_superpowers/skills
    ln -s ${superpowers-src}/skills "$skills_dest"
  '';

  pythonImportsCheck = ["id_hermes_superpowers"];
  doCheck = false;

  meta = {
    description = "Superpowers agentic development workflows for Hermes Agent";
    homepage = "https://github.com/obra/superpowers";
    license = lib.licenses.mit;
    maintainers = [];
    platforms = lib.platforms.unix;
  };
}
