from __future__ import annotations

import json
import os
from pathlib import Path

from hermes_cursor_harness.companion import install_cursor_companion
from hermes_cursor_harness.config import HarnessConfig


def test_install_cursor_companion_writes_cursor_files(tmp_path: Path, monkeypatch) -> None:
    monkeypatch.setenv("PATH", f"{tmp_path}{os.pathsep}{os.environ.get('PATH', '')}")
    project = tmp_path / "project"
    project.mkdir()
    wrapper = tmp_path / "hermes-cursor-harness-mcp"
    wrapper.write_text("#!/usr/bin/env bash\n", encoding="utf-8")
    wrapper.chmod(0o755)
    cfg = HarnessConfig(projects={"demo": str(project)}, state_dir=tmp_path / "state")

    result = install_cursor_companion(cfg=cfg, project_path=project)

    assert result["success"] is True
    assert (project / ".cursor/rules/hermes-harness.mdc").exists()
    assert (project / ".cursor/skills/hermes-context.md").exists()
    assert (project / ".cursor/environment.json").exists()
    assert (project / ".cursor/plugins/hermes-harness/index.json").exists()
    mcp = json.loads((project / ".cursor/mcp.json").read_text(encoding="utf-8"))
    assert "hermes-cursor-harness" in mcp["mcpServers"]
