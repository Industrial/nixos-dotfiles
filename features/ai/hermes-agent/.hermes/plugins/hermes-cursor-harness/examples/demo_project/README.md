# Hermes Cursor Harness Demo Project

This tiny project gives maintainers a harmless repository for smoke-testing
Cursor plan and edit flows.

## Configure

Copy the sample config into `~/.hermes/cursor_harness.json` or merge the
`projects.demo-project` entry into your existing config.

```bash
hermes-cursor-harness config validate --project demo-project
```

## Plan Smoke

```bash
hermes-cursor-harness smoke \
  --level real \
  --project demo-project \
  --security-profile trusted-local \
  --timeout-sec 180 \
  --json
```

## Hermes Tool Run

If your Hermes build exposes the plugin as tools, ask Hermes to use
`cursor_harness_run` with `project=demo-project`, `mode=plan`, and a prompt
such as:

```text
Inspect this demo project and tell me the test command. Do not edit files.
```

## Test Command

```bash
python -m pytest test_hello.py
```
