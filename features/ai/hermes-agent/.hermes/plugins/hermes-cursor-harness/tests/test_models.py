from __future__ import annotations

from hermes_cursor_harness.models import parse_models_output, parse_sdk_models


def test_parse_models_output() -> None:
    models = parse_models_output(
        """
Available models

auto - Auto
composer-2-fast - Composer 2 Fast (default)
gpt-5.3-codex - Codex 5.3

Tip: use --model <id>
"""
    )

    assert models == [
        {"id": "auto", "label": "Auto"},
        {"id": "composer-2-fast", "label": "Composer 2 Fast (default)"},
        {"id": "gpt-5.3-codex", "label": "Codex 5.3"},
    ]


def test_parse_sdk_models() -> None:
    models = parse_sdk_models(
        [
            {
                "id": "composer-2",
                "displayName": "Composer 2",
                "description": "Cursor coding model",
                "variants": [{"displayName": "Fast", "params": []}],
            }
        ]
    )

    assert models == [
        {
            "id": "composer-2",
            "label": "Composer 2",
            "description": "Cursor coding model",
            "variants": [{"displayName": "Fast", "params": []}],
        }
    ]
