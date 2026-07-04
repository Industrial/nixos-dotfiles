from __future__ import annotations

import sys
from pathlib import Path

from hermes_cursor_harness.compatibility import load_compatibility_records, run_and_record_compatibility
from hermes_cursor_harness.config import HarnessConfig
from hermes_cursor_harness.store import HarnessStore


def test_compatibility_run_records_quick_smoke(tmp_path: Path) -> None:
    fake_stream = Path(__file__).parent / "fakes" / "fake_cursor_stream.py"
    fake_acp = Path(__file__).parent / "fakes" / "fake_cursor_acp.py"
    cfg = HarnessConfig(
        stream_command=[sys.executable, str(fake_stream)],
        acp_command=[sys.executable, str(fake_acp)],
        state_dir=tmp_path / "state",
    )

    result = run_and_record_compatibility(cfg=cfg, store=HarnessStore(cfg.state_dir), level="quick")

    assert result["success"] is True
    records = load_compatibility_records(cfg)
    assert len(records) == 1
    assert records[0]["level"] == "quick"
    assert records[0]["schema_version"] == 2
    assert "environment" in records[0]
    assert records[0]["requested_checks"]["include_sdk"] is False
    assert records[0]["capabilities"]["bidirectional_backchannel"] == "pass"
