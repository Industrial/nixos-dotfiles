"""Hermes plugin entrypoint for the Cursor harness."""

from __future__ import annotations

import sys
from pathlib import Path

_PLUGIN_DIR = Path(__file__).resolve().parent
if str(_PLUGIN_DIR) not in sys.path:
    sys.path.insert(0, str(_PLUGIN_DIR))

from hermes_cursor_harness.plugin import register

__all__ = ["register"]
