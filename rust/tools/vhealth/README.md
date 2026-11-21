# vhealth

Service health from probes, not from systemd state. systemd reports what it
started, not what serves: a unit unchanged by a switch is not restarted (grafana
stayed `failed` across green deploys), an OCI container can be `inactive` while
it serves, and a unit can be `active` with its port closed. vhealth asks the
service.

Voltaic (`src/*.vlt`) on id_effect 0.13.0. Each probe is a fiber with its own
timeout; a check runs every probe at once and returns a structured verdict.

## Probes

| type      | passes when                                             | fields                              |
|-----------|---------------------------------------------------------|-------------------------------------|
| `tcp`     | a TCP connect to `host:port` succeeds                   | `host`, `port`                      |
| `http`    | an HTTP/1.0 GET answers `status` (and has `bodyContains`) | `url`, `status` (200), `bodyContains` |
| `unix`    | a connect to the unix stream socket succeeds            | `path`                              |
| `command` | `argv` (no shell) exits 0                               | `argv`                              |
| `file`    | the file was modified at most `maxAgeSeconds` ago       | `path`, `maxAgeSeconds`             |

Every probe also has `timeoutMs` (default 5000) and `critical` (default true).
A probe is up or down, never unknown: a timeout, a refused connect, a wrong status
and a missing file are all down, with the reason in `detail`. **The host is healthy
when no critical probe is down**; a non-critical probe that is down is reported and
exported but does not make the host unhealthy.

On NixOS, probes are declared by the feature that owns the service, as
`features.nix.vhealth.probes.<name>` (features/nix/vhealth), and land in
`/etc/vhealth/probes.json`:

```json
{"probes": [
  {"name": "sshd", "type": "tcp", "host": "100.69.213.35", "port": 22},
  {"name": "vcache", "type": "http", "url": "http://100.69.213.35:5100/nix-cache-info",
   "bodyContains": "StoreDir: /nix/store", "timeoutMs": 3000}
]}
```

## CLI

```
vhealth check  [--config FILE] [--json] [--probe NAME]... [--wait DURATION] [--every DURATION]
vhealth daemon [--config FILE] [--interval DURATION] [--textfile-dir DIR]
```

- `vhealth check` runs every probe once (or the `--probe`s named) and exits **0 when
  healthy, 1 when a critical probe is down** (the id_effect_cli taxonomy: 101 is a
  defect, 130 an interrupt). The report goes to stdout: one line per probe, or one
  JSON document with `--json`.
- `--wait 2m` makes it a settle window: an unhealthy check is repeated every
  `--every` (default 2s) until it is healthy or the window has passed, and the exit
  code is the last check's.
- `vhealth daemon` checks every `--interval` (default 1m) on an id_effect Schedule
  and writes `vhealth.prom` and `vhealth.json` into the node_exporter textfile
  directory, each atomically.

The JSON report:

```json
{"healthy": false, "finished": 1795258000,
 "failing": ["liar"], "down": ["liar", "vverify-metrics"],
 "probes": [{"name": "liar", "kind": "tcp", "critical": true, "up": false,
             "detail": "127.0.0.1:8081: Connection refused (os error 111)", "millis": 0}, …]}
```

The metrics: `vhealth_probe_up{probe,kind,critical}` (1/0),
`vhealth_probe_duration_seconds{probe,kind,critical}`, `vhealth_healthy`,
`vhealth_probes_down`, `vhealth_last_check_timestamp_seconds`.

## Library API (for vdeploy, #159/#160)

vdeploy decides whether to keep or roll back a switch from this API. Depend on it
by path, like nix-store-core: `vhealth = { path = "../vhealth" }`, with the same
`id_effect = "=0.13.0"`.

```rust
use std::time::Duration;
use vhealth::{check, config, probe};

// The probes the *new* generation declares: its /etc/vhealth/probes.json, or
// <toplevel>/etc/vhealth/probes.json before /etc is switched.
let probes: Vec<probe::Probe> = config::load(config::DEFAULT_CONFIG)?;      // Result<_, String>

// One check, every probe at once, each under its timeout.
let now: Effect<probe::Report, Never, HNil> = check::check(probes.clone());

// After a switch: re-check every 2s while a critical probe is down, for at most 2m.
// Succeeds with the first healthy report, or the last unhealthy one.
let settled: Effect<probe::Report, Never, HNil> =
    check::settle(probes, Duration::from_secs(120), Duration::from_secs(2));

// The decision, and what to log or put in the rollback message.
probe::healthy(&report)        // bool: no critical probe down -> keep the generation
probe::failing(&report)        // Vec<String>: critical probes down (why it rolls back)
probe::down(&report)           // Vec<String>: every probe down, critical or not
report::json(&report)          // the JSON document above
report::human(&report)         // the text `vhealth check` prints
```

The pieces, all `pub`:

| item | type | |
|------|------|-|
| `config::load(path)` / `config::parse(text)` | `-> Result<Vec<Probe>, String>` | the configuration, parsed in one step |
| `config::select(probes, &names)` | `-> Result<Vec<Probe>, String>` | a subset, by name |
| `check::check(probes)` | `-> Effect<Report, Never, HNil>` | one check; never fails |
| `check::settle(probes, within, every)` | `-> Effect<Report, Never, HNil>` | the settle window; never fails |
| `check::run(probe)` | `-> Effect<Outcome, Never, HNil>` | one probe |
| `probe::{Probe, Kind, HttpCheck}` | data | `Kind::{Tcp, Http, Unix, Command, File}` |
| `probe::{Report, Outcome}` | data | `Report { finished, outcomes }`, `Outcome { name, kind, critical, up, detail, millis }` |
| `report::{json, human, metrics, publish}` | pure renderers, one atomic write | |

Two things a consumer must do:

1. **Run the effects on a tokio-backed fiber.** The probes' sockets and child
   processes are tokio's. `id_effect_cli::run_main` and `Runtime::block_on` poll
   their root on the calling thread, outside the reactor, so fork the program and
   join it (`app.vlt`'s `supervised`, vcache's and vverify's the same). `File`
   probes need no reactor and run on a `TestExecutor` too, which is how the settle
   logic is tested.
2. **Decide on `healthy`, not on `down`.** Non-critical probes (vverify's metrics
   freshness, say) are down for reasons a rollback cannot fix.

Timeouts are real: a probe's I/O is a future raced against a sleep on the
executor clock, and the loser is dropped, so a hung connect is abandoned and a
hung command is killed (`kill_on_drop`). `settle` bounds its window with
`Schedule::spaced(every).up_to(within)`, so it takes at most `within` plus one
check (whose length is bounded by the largest probe timeout).
