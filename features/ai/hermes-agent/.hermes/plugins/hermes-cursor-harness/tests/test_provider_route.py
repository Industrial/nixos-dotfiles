from __future__ import annotations

import json
import subprocess
from pathlib import Path

from hermes_cursor_harness.provider_route import validate_provider_route, write_provider_route_bundle


def test_provider_route_validation_reports_missing_markers(tmp_path: Path) -> None:
    hermes = tmp_path / "hermes"
    hermes.mkdir()

    result = validate_provider_route(hermes)

    assert result["success"] is False
    assert any(item["path"] == "run_agent.py" for item in result["missing"])


def test_provider_route_bundle_writes_manifest(tmp_path: Path) -> None:
    bundle = tmp_path / "bundle"

    result = write_provider_route_bundle(hermes_root=None, output_dir=bundle)

    assert result["success"] is True
    manifest = json.loads((bundle / "provider-route-manifest.json").read_text(encoding="utf-8"))
    assert "required_changes" in manifest
    assert (bundle / "README.md").exists()


def test_provider_route_bundle_exports_git_patch_for_untracked_route_file(tmp_path: Path) -> None:
    hermes = tmp_path / "hermes"
    (hermes / "agent").mkdir(parents=True)
    (hermes / "agent" / "cursor_harness_adapter.py").write_text(
        "CURSOR_HARNESS_PROVIDER = 'cursor-harness'\n"
        "def run_cursor_harness_provider_turn():\n"
        "    pass\n",
        encoding="utf-8",
    )
    subprocess.run(["git", "init"], cwd=hermes, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    bundle = tmp_path / "bundle"

    result = write_provider_route_bundle(hermes_root=hermes, output_dir=bundle)

    patch = bundle / "cursor-provider-route.patch"
    assert result["success"] is True
    assert patch.exists()
    assert "cursor_harness_adapter.py" in patch.read_text(encoding="utf-8")
