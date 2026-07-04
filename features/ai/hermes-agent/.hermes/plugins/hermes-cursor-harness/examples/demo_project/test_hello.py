from hello import greeting


def test_greeting_uses_default_name() -> None:
    assert greeting() == "Hello, Hermes. Cursor is connected."


def test_greeting_normalizes_whitespace() -> None:
    assert greeting("  Cursor   Harness  ") == "Hello, Cursor Harness. Cursor is connected."
